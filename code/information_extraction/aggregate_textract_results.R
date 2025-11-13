#!/usr/bin/env Rscript

# Aggregate Textract JSON Results
# This script reads all Textract JSON files from the eds_forms_textract directory
# and aggregates the extracted information into a single dataframe

# Load required libraries
library(jsonlite)
library(dplyr)
library(purrr)
library(stringr)
library(readr)

# Configuration
INPUT_DIR <- "data/intermediate_products/eds_forms_textract"
OUTPUT_DIR <- "data/intermediate_products"
OUTPUT_FILE <- "textract_aggregated_results.csv"

cat("Starting Textract JSON aggregation...\n")
cat("Input directory:", INPUT_DIR, "\n")
cat("Output file:", file.path(OUTPUT_DIR, OUTPUT_FILE), "\n\n")

# Function to extract key-value pairs from Textract JSON
extract_key_value_pairs <- function(json_data) {
  # Initialize result list
  result <- list()
  
  # Check if Blocks exist
  if (!"Blocks" %in% names(json_data)) {
    return(result)
  }
  
  blocks <- json_data$Blocks
  
  # Find KEY_VALUE_SET blocks
  key_value_blocks <- blocks[sapply(blocks, function(x) x$BlockType == "KEY_VALUE_SET")]
  
  # Separate KEY and VALUE blocks
  key_blocks <- key_value_blocks[sapply(key_value_blocks, function(x) {
    "EntityTypes" %in% names(x) && "KEY" %in% x$EntityTypes
  })]
  
  value_blocks <- key_value_blocks[sapply(key_value_blocks, function(x) {
    "EntityTypes" %in% names(x) && "VALUE" %in% x$EntityTypes
  })]
  
  # Create lookup for VALUE blocks by ID
  value_lookup <- setNames(value_blocks, sapply(value_blocks, function(x) x$Id))
  
  # Process each KEY block
  for (key_block in key_blocks) {
    # Get key text
    key_text <- extract_text_from_block(key_block, blocks)
    
    # Find associated VALUE block
    value_text <- ""
    if ("Relationships" %in% names(key_block)) {
      value_relationships <- key_block$Relationships[sapply(key_block$Relationships, function(x) x$Type == "VALUE")]
      
      if (length(value_relationships) > 0 && "Ids" %in% names(value_relationships[[1]])) {
        value_id <- value_relationships[[1]]$Ids[[1]]
        if (value_id %in% names(value_lookup)) {
          value_block <- value_lookup[[value_id]]
          value_text <- extract_text_from_block(value_block, blocks)
        }
      }
    }
    
    # Clean and store key-value pair
    if (nchar(key_text) > 0) {
      clean_key <- clean_text(key_text)
      result[[clean_key]] <- clean_text(value_text)
    }
  }
  
  return(result)
}

# Function to extract text from a block using relationships
extract_text_from_block <- function(block, all_blocks) {
  if (!"Relationships" %in% names(block)) {
    return("")
  }
  
  # Find CHILD relationships
  child_relationships <- block$Relationships[sapply(block$Relationships, function(x) x$Type == "CHILD")]
  
  if (length(child_relationships) == 0) {
    return("")
  }
  
  # Get child IDs
  child_ids <- unlist(lapply(child_relationships, function(x) x$Ids))
  
  # Create lookup for all blocks
  block_lookup <- setNames(all_blocks, sapply(all_blocks, function(x) x$Id))
  
  # Extract text from WORD blocks
  text_parts <- c()
  for (child_id in child_ids) {
    if (child_id %in% names(block_lookup)) {
      child_block <- block_lookup[[child_id]]
      if (child_block$BlockType == "WORD" && "Text" %in% names(child_block)) {
        text_parts <- c(text_parts, child_block$Text)
      }
    }
  }
  
  return(paste(text_parts, collapse = " "))
}

# Function to clean text
clean_text <- function(text) {
  if (is.null(text) || length(text) == 0) {
    return("")
  }
  
  # Remove extra whitespace and trim
  cleaned <- str_trim(str_squish(as.character(text)))
  
  # Remove common form artifacts
  cleaned <- str_remove_all(cleaned, "^[:\\-\\s]+|[:\\-\\s]+$")
  
  return(cleaned)
}

# Function to standardize column names
standardize_column_name <- function(name) {
  # Convert to lowercase
  name <- tolower(name)
  
  # Replace common variations
  name <- str_replace_all(name, c(
    "environmental data sheet" = "eds",
    "eds number" = "eds_number", 
    "eds #" = "eds_number",
    "eds no" = "eds_number",
    "date prepared" = "date_prepared",
    "prepared date" = "date_prepared",
    "date created" = "date_prepared",
    "created date" = "date_prepared"
  ))
  
  # Remove punctuation and replace spaces with underscores
  name <- str_replace_all(name, "[^a-z0-9\\s]", "")
  name <- str_replace_all(name, "\\s+", "_")
  
  # Remove leading/trailing underscores
  name <- str_remove_all(name, "^_+|_+$")
  
  return(name)
}

# Function to parse filename components
parse_filename <- function(filename) {
  # Extract base filename without extension
  base_name <- str_remove(filename, "_page_\\d+_textract\\.json$")
  
  # Extract page number
  page_match <- str_extract(filename, "page_(\\d+)", group = 1)
  page_number <- as.numeric(page_match)
  
  list(
    original_filename = paste0(base_name, ".pdf"),
    base_name = base_name,
    page_number = page_number,
    textract_filename = filename
  )
}

# Function to process a single Textract JSON file
process_single_textract_file <- function(file_path) {
  filename <- basename(file_path)
  
  tryCatch({
    # Parse filename
    file_info <- parse_filename(filename)
    
    # Read JSON
    json_data <- fromJSON(file_path, flatten = FALSE)
    
    # Extract key-value pairs
    kv_pairs <- extract_key_value_pairs(json_data)
    
    # Create result row
    result_row <- c(
      list(
        filename = file_info$original_filename,
        base_name = file_info$base_name,
        page_number = file_info$page_number,
        textract_filename = filename,
        processed = TRUE,
        num_fields_extracted = length(kv_pairs)
      ),
      kv_pairs
    )
    
    return(result_row)
    
  }, error = function(e) {
    cat("Error processing", filename, ":", e$message, "\n")
    
    file_info <- parse_filename(filename)
    error_row <- list(
      filename = file_info$original_filename,
      base_name = file_info$base_name, 
      page_number = file_info$page_number,
      textract_filename = filename,
      processed = FALSE,
      num_fields_extracted = 0,
      error = e$message
    )
    
    return(error_row)
  })
}
library(data.table)
library(pbapply)
jlist = list.files('data/intermediate_products/eds_forms_textract/',pattern = 'json',full.names = T)

qlist1 = pblapply(jlist,function(j){
  js = fromJSON(j)
  if(any(js$Blocks$BlockType %in% 'QUERY_RESULT')){
    dt = data.table(t(data.table(js$Blocks[js$Blocks$BlockType %in% 'QUERY_RESULT',]$Text)))
    # Find indices where current element is "QUERY" and next is "QUERY_RESULT"
    query_text <- js$Blocks[which(js$Blocks$BlockType=='QUERY_RESULT')-1,]$Query[[1]]
    colnames(dt) <- query_text
    dt$FILE <- basename(j)
    dt}
  },cl =8
)


tlist = list.files('data/intermediate_products/eds_forms_textract_textblurbs/',pattern = 'json',full.names = T)
qlist2 = pblapply(tlist,function(j){
  js = fromJSON(j)
  if(any(js$Blocks$BlockType %in% 'QUERY_RESULT')){
    dt = data.table(t(data.table(js$Blocks[js$Blocks$BlockType %in% 'QUERY_RESULT',]$Text)))
    # Find indices where current element is "QUERY" and next is "QUERY_RESULT"
    query_text <- js$Blocks[which(js$Blocks$BlockType=='QUERY_RESULT')-1,]$Query[[1]]
    colnames(dt) <- query_text
    dt$FILE <- basename(j)
    dt}
},cl =8
)

q1 <- rbindlist(qlist1,use.names = T,fill = T)
q2 <- rbindlist(qlist2,use.names = T,fill = T)

test <- merge(q1,q2)

duplicated(q2$`EDS Number`)
q2[`EDS Number`=='A249-6-320346',]

ts = fromJSON(tlist[1])
tt = data.table(t(data.table(ts$Blocks[ts$Blocks$BlockType == 'QUERY_RESULT',]$Text)))
colnames(tt) <- ts$Blocks[ts$Blocks$BlockType == 'QUERY',]$Query[[1]]






dt = data.table(query = js$Blocks$Query$Text,text = js$Blocks$Text)
dt |> filter(!is.na(query))

js$ResponseMetadata$

process_single_textract_file(js[1])
# Function to aggregate multiple Textract results into a dataframe
aggregate_textract_results <- function(results_list) {
  cat("Converting", length(results_list), "results to dataframe...\n")
  
  # Get all unique column names
  all_columns <- unique(unlist(lapply(results_list, names)))
  
  # Standardize column names (except core columns)
  core_columns <- c("filename", "base_name", "page_number", "textract_filename", 
                   "processed", "num_fields_extracted", "error")
  
  standardized_columns <- all_columns
  non_core_idx <- !all_columns %in% core_columns
  standardized_columns[non_core_idx] <- sapply(all_columns[non_core_idx], standardize_column_name)
  
  # Create mapping
  column_mapping <- setNames(standardized_columns, all_columns)
  
  # Apply mapping to each result
  standardized_results <- lapply(results_list, function(result) {
    new_names <- column_mapping[names(result)]
    setNames(result, new_names)
  })
  
  # Convert to dataframe
  df <- bind_rows(standardized_results)
  
  # Fill missing values with NA
  df[is.na(df)] <- NA
  
  # Reorder columns (core columns first)
  core_cols_present <- intersect(core_columns, names(df))
  other_cols <- setdiff(names(df), core_columns)
  df <- df[, c(core_cols_present, sort(other_cols))]
  
  return(df)
}

# Main processing function that coordinates the workflow
process_textract_files <- function(sample = FALSE) {
  # Get all JSON files
  json_files <- list.files(INPUT_DIR, pattern = "_textract\\.json$", full.names = TRUE)
  
  # Apply sampling if requested
  if (is.numeric(sample) && sample > 0) {
    json_files <- sample(json_files, min(sample, length(json_files)))
  }
  
  if (length(json_files) == 0) {
    stop("No Textract JSON files found in ", INPUT_DIR)
  }
  
  cat("Found", length(json_files), "JSON files to process\n\n")
  
  # Process each file using the single file function
  all_results <- list()
  
  for (i in seq_along(json_files)) {
    if (i %% 100 == 0) {
      cat("Processing file", i, "of", length(json_files), "\n")
    }
    
    all_results[[i]] <- process_single_textract_file(json_files[i])
  }
  
  cat("Completed processing all files\n\n")
  
  # Aggregate results into dataframe
  df <- aggregate_textract_results(all_results)
  
  return(df)
}

# Run the processing
cat("Starting processing...\n")
results_df <- process_textract_files(sample = 4)

# Summary statistics
cat("\\nSummary:\n")
cat("Total files processed:", nrow(results_df), "\n")
cat("Successfully processed:", sum(results_df$processed, na.rm = TRUE), "\n")
cat("Failed:", sum(!results_df$processed, na.rm = TRUE), "\n")
cat("Total columns:", ncol(results_df), "\n")

# Show most common extracted fields
if (ncol(results_df) > 10) {
  non_core_cols <- setdiff(names(results_df), c("filename", "base_name", "page_number", 
                                                "textract_filename", "processed", 
                                                "num_fields_extracted", "error"))
  
  field_counts <- sapply(non_core_cols, function(col) sum(!is.na(df[[col]]) & df[[col]] != ""))
  top_fields <- sort(field_counts, decreasing = TRUE)[1:min(10, length(field_counts))]
  
  cat("\\nTop extracted fields:\n")
  for (i in seq_along(top_fields)) {
    cat(sprintf("  %s: %d files (%.1f%%)\n", 
               names(top_fields)[i], 
               top_fields[i], 
               100 * top_fields[i] / nrow(results_df)))
  }
}

# Save results
output_path <- file.path(OUTPUT_DIR, OUTPUT_FILE)
write_csv(results_df, output_path)

cat("\\nResults saved to:", output_path, "\n")
cat("\\nFirst few rows:\n")
print(head(results_df, 3))

cat("\\nAggregation complete!\n")