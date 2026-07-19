use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::ffi::{CStr, CString, c_char};
use toml_edit::{Array, DocumentMut, Item, Table, Value, value as toml_value};

#[derive(Serialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
enum BridgeValue {
    Table(BTreeMap<String, BridgeValue>),
    Array(Vec<BridgeValue>),
    String(String),
    Integer(i64),
    Float(String),
    Boolean(bool),
    Datetime(String),
}

#[derive(Serialize)]
struct ParseResponse {
    ok: bool,
    value: Option<BridgeValue>,
    error: Option<BridgeError>,
}

#[derive(Serialize)]
struct EditResponse {
    ok: bool,
    text: Option<String>,
    error: Option<BridgeError>,
}

#[derive(Serialize)]
struct BridgeError {
    message: String,
    start: Option<usize>,
    end: Option<usize>,
}

#[derive(Deserialize)]
struct EditRequest {
    edits: Vec<Edit>,
}

#[derive(Deserialize)]
struct Edit {
    path: Vec<String>,
    value: EditValue,
}

#[derive(Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
enum EditValue {
    String(String),
    Integer(i64),
    Float(f64),
    Boolean(bool),
    StringArray(Vec<String>),
}

fn table_value(table: &Table) -> BridgeValue {
    BridgeValue::Table(
        table
            .iter()
            .filter_map(|(key, item)| item_value(item).map(|value| (key.to_owned(), value)))
            .collect(),
    )
}

fn item_value(item: &Item) -> Option<BridgeValue> {
    match item {
        Item::None => None,
        Item::Value(value) => Some(value_value(value)),
        Item::Table(table) => Some(table_value(table)),
        Item::ArrayOfTables(array) => {
            Some(BridgeValue::Array(array.iter().map(table_value).collect()))
        }
    }
}

fn value_value(value: &Value) -> BridgeValue {
    match value {
        Value::String(value) => BridgeValue::String(value.value().to_owned()),
        Value::Integer(value) => BridgeValue::Integer(*value.value()),
        Value::Float(value) => BridgeValue::Float(value.value().to_string()),
        Value::Boolean(value) => BridgeValue::Boolean(*value.value()),
        Value::Datetime(value) => BridgeValue::Datetime(value.value().to_string()),
        Value::Array(array) => BridgeValue::Array(array.iter().map(value_value).collect()),
        Value::InlineTable(table) => BridgeValue::Table(
            table
                .iter()
                .map(|(key, value)| (key.to_owned(), value_value(value)))
                .collect(),
        ),
    }
}

fn parse_error(error: toml_edit::TomlError) -> BridgeError {
    let span = error.span();
    BridgeError {
        message: error.message().to_owned(),
        start: span.as_ref().map(|span| span.start),
        end: span.map(|span| span.end),
    }
}

fn bridge_error(message: impl Into<String>) -> BridgeError {
    BridgeError {
        message: message.into(),
        start: None,
        end: None,
    }
}

fn response_string<T: Serialize>(response: &T) -> *mut c_char {
    let json = serde_json::to_string(response).unwrap_or_else(|error| {
        format!(
            r#"{{"ok":false,"error":{{"message":{:?},"start":null,"end":null}}}}"#,
            error.to_string()
        )
    });
    CString::new(json)
        .expect("JSON cannot contain NUL")
        .into_raw()
}

unsafe fn input_string(input: *const c_char) -> Result<String, BridgeError> {
    if input.is_null() {
        return Err(bridge_error("input pointer is null"));
    }
    // SAFETY: callers provide a NUL-terminated UTF-8 C string for the duration of this call.
    let bytes = unsafe { CStr::from_ptr(input) }.to_bytes();
    String::from_utf8(bytes.to_vec()).map_err(|_| bridge_error("input is not valid UTF-8"))
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn easybar_toml_parse(input: *const c_char) -> *mut c_char {
    let response = match unsafe { input_string(input) } {
        Ok(text) => match text.parse::<DocumentMut>() {
            Ok(document) => ParseResponse {
                ok: true,
                value: Some(table_value(document.as_table())),
                error: None,
            },
            Err(error) => ParseResponse {
                ok: false,
                value: None,
                error: Some(parse_error(error)),
            },
        },
        Err(error) => ParseResponse {
            ok: false,
            value: None,
            error: Some(error),
        },
    };
    response_string(&response)
}

fn edit_item(edit_value: EditValue) -> Item {
    match edit_value {
        EditValue::String(value) => toml_value(value),
        EditValue::Integer(value) => toml_value(value),
        EditValue::Float(value) => toml_value(value),
        EditValue::Boolean(value) => toml_value(value),
        EditValue::StringArray(values) => {
            let mut array = Array::new();
            for value in values {
                array.push(value);
            }
            Item::Value(Value::Array(array))
        }
    }
}

fn apply_edit(document: &mut DocumentMut, edit: Edit) -> Result<(), BridgeError> {
    let (key, tables) = edit
        .path
        .split_last()
        .ok_or_else(|| bridge_error("edit path must not be empty"))?;
    let mut table = document.as_table_mut();
    for component in tables {
        if !table.contains_key(component) {
            table.insert(component, Item::Table(Table::new()));
        }
        table = table
            .get_mut(component)
            .and_then(Item::as_table_mut)
            .ok_or_else(|| bridge_error(format!("{} is not a TOML table", component)))?;
    }
    let mut replacement = edit_item(edit.value);
    if let Some((_formatted_key, existing)) = table.get_key_value_mut(key) {
        if let (Some(existing_value), Some(replacement_value)) =
            (existing.as_value(), replacement.as_value_mut())
        {
            *replacement_value.decor_mut() = existing_value.decor().clone();
        }
        *existing = replacement;
    } else {
        table.insert(key, replacement);
    }
    Ok(())
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn easybar_toml_edit(
    input: *const c_char,
    request_json: *const c_char,
) -> *mut c_char {
    let result = (|| {
        let text = unsafe { input_string(input) }?;
        let request = unsafe { input_string(request_json) }?;
        let mut document = text.parse::<DocumentMut>().map_err(parse_error)?;
        let request: EditRequest = serde_json::from_str(&request)
            .map_err(|error| bridge_error(format!("invalid edit request: {error}")))?;
        for edit in request.edits {
            apply_edit(&mut document, edit)?;
        }
        let mut output = document.to_string();
        if !text.ends_with('\n') && output.ends_with('\n') {
            output.pop();
        }
        Ok::<String, BridgeError>(output)
    })();

    match result {
        Ok(text) => response_string(&EditResponse {
            ok: true,
            text: Some(text),
            error: None,
        }),
        Err(error) => response_string(&EditResponse {
            ok: false,
            text: None,
            error: Some(error),
        }),
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn easybar_toml_string_free(value: *mut c_char) {
    if !value.is_null() {
        // SAFETY: the pointer was returned by CString::into_raw in this library.
        drop(unsafe { CString::from_raw(value) });
    }
}
