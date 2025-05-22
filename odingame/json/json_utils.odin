package json

import "core:encoding/json"
import "core:os"
import "core:io"
import "core:log"
import "core:fmt"
import "core:mem"

// parse_json_from_file reads a JSON file and unmarshals its content into the provided data structure.
// Parameters:
//   filepath: The path to the JSON file.
//   data_struct_ptr: A pointer to an Odin struct instance that the JSON data should be mapped to.
//   allocator: The memory allocator to use for dynamic data within the unmarshalled struct.
//   $T: The type of the data structure, inferred by the compiler.
// Returns:
//   json.Unmarshal_Error: An error object indicating success or failure. Nil on success.
parse_json_from_file :: proc(
	filepath: string, 
	data_struct_ptr: ^$T, 
	allocator := context.allocator, 
	$T: typeid, // Make T explicit for clarity, though ^$T usually infers it.
) -> (err: json.Unmarshal_Error) {
	
	if data_struct_ptr == nil {
		log.errorf("parse_json_from_file: data_struct_ptr cannot be nil. Filepath: %s", filepath)
		// Cannot return Unmarshal_Error directly here as it's a union.
		// Need to pick a specific error variant or have a generic one.
		// For now, let's assume returning one of its variants, e.g. Unmarshal_Data_Error
		return json.Unmarshal_Data_Error.Invalid_Parameter
	}

	data_bytes, file_err := os.read_entire_file(filepath, allocator)
	if file_err != os.ERROR_NONE {
		// os.Error is not directly convertible to json.Unmarshal_Error.
		// We need to log the OS error and return a relevant json.Unmarshal_Error.
		log.errorf("Failed to read file '%s': %v", filepath, file_err)
		// Let's use a generic json.Error for this case.
		// This requires knowing how to construct a json.Error, or returning a specific Unmarshal_Data_Error.
		// For simplicity, let's use a generic data error.
		// The json.Error enum includes things like EOF, Illegal_Character etc.
		// This doesn't quite fit.
		// Returning a specific Unmarshal_Data_Error might be best.
		return json.Unmarshal_Data_Error.Invalid_Data // Or a new error type for "File_Read_Error"
	}
	defer delete(data_bytes, allocator) // Ensure file content buffer is freed

	unmarshal_err := json.unmarshal(data_bytes, data_struct_ptr, .JSON5, allocator) // Using JSON5 as default spec
	
	if unmarshal_err != nil {
		// The error from json.unmarshal is already json.Unmarshal_Error union
		log.errorf("Failed to unmarshal JSON from file '%s': %v", filepath, unmarshal_err)
		return unmarshal_err
	}

	log.infof("Successfully parsed JSON from file '%s' into type %v", filepath, T)
	return nil // Success
}


// parse_json_from_string unmarshals JSON content from a string into the provided data structure.
// Parameters:
//   json_string: The JSON string to parse.
//   data_struct_ptr: A pointer to an Odin struct instance that the JSON data should be mapped to.
//   allocator: The memory allocator to use for dynamic data.
//   $T: The type of the data structure, inferred by the compiler.
// Returns:
//   json.Unmarshal_Error: An error object. Nil on success.
parse_json_from_string :: proc(
	json_string: string, 
	data_struct_ptr: ^$T, 
	allocator := context.allocator,
	$T: typeid,
) -> (err: json.Unmarshal_Error) {

	if data_struct_ptr == nil {
		log.error("parse_json_from_string: data_struct_ptr cannot be nil.")
		return json.Unmarshal_Data_Error.Invalid_Parameter
	}

	// json.unmarshal_string takes a string directly.
	unmarshal_err := json.unmarshal_string(json_string, data_struct_ptr, .JSON5, allocator) // Using JSON5 as default
	
	if unmarshal_err != nil {
		log.errorf("Failed to unmarshal JSON from string: %v", unmarshal_err)
		// Log a snippet of the string for context, careful with large strings.
		// snippet_len := 100
		// if len(json_string) < snippet_len { snippet_len = len(json_string) }
		// log.debugf("JSON string snippet: %s", json_string[:snippet_len])
		return unmarshal_err
	}

	log.infof("Successfully parsed JSON from string into type %v", T)
	return nil // Success
}


// write_json_to_file serializes the provided data structure to JSON and writes it to a file.
// Parameters:
//   filepath: The path to the output JSON file.
//   data_struct: The Odin struct instance to serialize. (Using `any` as json.marshal takes `any`)
//   allocator: The memory allocator to use for marshalling.
//   pretty: If true, output formatted (indented) JSON.
// Returns:
//   json.Marshal_Error: An error object. Nil on success.
//   os.Error: For file I/O errors. (Returning two errors is not Odin idiomatic, combine or handle)
// Let's return a single error type, preferably by extending Gfx_Error or a new Json_Util_Error.
// For now, returning Marshal_Error and logging file errors. A better solution would be a custom error union.
// Or, simply return json.Marshal_Error and handle file errors by returning a specific variant if possible,
// or just log and return a generic Marshal_Error.
// Subtask asks for `-> (err: json.Marshal_Error)`. This means file I/O errors need to be wrapped or handled.
write_json_to_file :: proc(
	filepath: string, 
	data_struct: any, // json.marshal takes `any`
	allocator := context.allocator, 
	pretty := false,
) -> (err: json.Marshal_Error) {

	marshal_options := json.Marshal_Options{
		spec = .JSON5, // Default to JSON5 for consistency with parsing
		pretty = pretty,
		// use_spaces = true, // Default is false (tabs)
		// spaces = 4,        // Default is 4 if use_spaces is true
	}
	
	json_bytes, marshal_err := json.marshal(data_struct, marshal_options, allocator)
	if marshal_err != nil {
		log.errorf("Failed to marshal data to JSON for file '%s': %v", filepath, marshal_err)
		return marshal_err
	}
	defer delete(json_bytes, allocator) // Ensure marshalled bytes are freed

	write_err := os.write_entire_file(filepath, json_bytes)
	if write_err != os.ERROR_NONE {
		log.errorf("Failed to write JSON to file '%s': %v", filepath, write_err)
		// How to represent this as json.Marshal_Error?
		// json.Marshal_Error is union { Marshal_Data_Error, io.Error }
		// os.Error is not io.Error. This is problematic.
		// For now, returning a generic Marshal_Data_Error.Unsupported_Type (misnomer here).
		// A better solution: define a custom error union for this utility that includes os.Error.
		// Or, the Marshal_Error union in core:encoding/json should ideally include os.File_Error or similar.
		// Let's assume for now that if file write fails, we return a generic data error.
		// This is not ideal.
		// A simple fix: if io.Error is expected, try to map os.Error to an io.Error conceptually.
		// For the stub, let's just return a generic Marshal_Data_Error.
		return json.Marshal_Data_Error.Unsupported_Type // Placeholder for "FileWriteError"
	}

	log.infof("Successfully wrote JSON data to file '%s'. Pretty: %v", filepath, pretty)
	return nil // Success
}

// --- Conceptual Example Struct and Test ---
/*
// This would typically be in a test file or example usage code.

Test_Config :: struct {
	version:  string,
	settings: map[string]int,
	feature_flags: []string,
	user_details: Maybe(User_Detail_Struct), // Example of optional nested struct
}

User_Detail_Struct :: struct {
	name: string,
	id:   int,
}

// Conceptual test:
// main :: proc() {
//  context.allocator = mem.heap_allocator() // Ensure an allocator is set
//  defer mem.destroy_heap_allocator(&context.allocator)
// 
//  // Create a sample JSON file "config.json":
//  // {
//  //  "version": "1.0.5",
//  //  "settings": {
//  //      "volume": 75,
//  //      "difficulty": 2
//  //  },
//  //  "feature_flags": ["alpha", "beta_feature"],
//  //  "user_details": {"name": "Odin User", "id": 12345}
//  // }
//  // Or, if user_details is null:
//  // {
//  //  "version": "1.0.5",
//  //  "settings": { "volume": 75, "difficulty": 2 },
//  //  "feature_flags": ["alpha", "beta_feature"],
//  //  "user_details": null
//  // }
//
//  config_instance: Test_Config
//
//  // Test parsing from file
//  parse_err := parse_json_from_file("config.json", &config_instance)
//  if parse_err != nil {
//      log.fatalf("Failed to parse config.json: %v", parse_err)
//  }
//  fmt.printf("Parsed from file: %+v\n", config_instance)
//  // Remember to free map and slice data if necessary, though unmarshal should use the provided allocator.
//  // For maps/slices in config_instance, if they are non-nil, they would need to be deleted
//  // using the same allocator before config_instance goes out of scope if it's a stack variable,
//  // or when the containing struct is destroyed.
//  // json.destroy_value can be used if you parse to json.Value first.
//  // For direct unmarshal to struct, field memory (maps, slices) is managed by the allocator.
//  // `delete(config_instance.settings, context.allocator)`
//  // `delete(config_instance.feature_flags, context.allocator)`
//  // If config_instance itself is heap allocated, its fields will be freed with it if allocator is consistent.
//
//  // Test parsing from string
//  json_data_str := `{"version": "2.0", "settings": {"sfx": 100}, "feature_flags": ["gamma"]}`
//  config_from_string: Test_Config
//  parse_str_err := parse_json_from_string(json_data_str, &config_from_string)
//  if parse_str_err != nil {
//      log.fatalf("Failed to parse JSON string: %v", parse_str_err)
//  }
//  fmt.printf("Parsed from string: %+v\n", config_from_string)
//
//  // Test writing to file
//  config_to_write := Test_Config{
//      version = "1.1.0",
//      settings = map[string]int{"master_volume": 90, "music_volume": 60},
//      feature_flags = []string{"new_feature", "experimental"},
//      user_details = Maybe(User_Detail_Struct){User_Detail_Struct{"Test User", 789}, true},
//  }
//  // Need to make the map and slice if literal
//  // config_to_write.settings = make(map[string]int, context.allocator)
//  // config_to_write.settings["master_volume"] = 90
//  // config_to_write.feature_flags = make([dynamic]string, context.allocator)
//  // append(&config_to_write.feature_flags, "new_feature")
// 
//  write_err := write_json_to_file("output_config.json", config_to_write, pretty = true)
//  if write_err != nil {
//      log.fatalf("Failed to write JSON to file: %v", write_err)
//  }
//  fmt.println("Wrote config to output_config.json")
//
//  // Cleanup for heap-allocated maps/slices in config_to_write if it were to be done manually here.
//  // delete(config_to_write.settings)
//  // delete(config_to_write.feature_flags)
// }
*/
