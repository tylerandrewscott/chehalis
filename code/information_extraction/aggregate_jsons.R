library(jsonlite)
library(stringr)

# List all JSON files in the intermediate products directory
json_files <- list.files(path = "data/intermediate_products/json_forms", 
                        pattern = "\\.json$", 
                        full.names = TRUE)

# Initialize empty list to store data frames
raw_data <- list()

library(jsonlite)

fix_json <- function(json_str) {
  # Remove trailing commas
  json_str <- gsub(",\\s*([}\\]])", "\\1", json_str)
  
  # Count opening and closing braces
  open_braces <- gregexpr("\\{", json_str)[[1]]
  close_braces <- gregexpr("\\}", json_str)[[1]]
  
  # Add missing closing braces
  if (length(open_braces) > length(close_braces)) {
    json_str <- paste0(json_str, strrep("}", length(open_braces) - length(close_braces)))
  }
  
  # Attempt to parse the JSON
  parsed_json <- tryCatch({
    fromJSON(json_str)
  }, error = function(e) {
    message("Error parsing JSON: ", e$message)
    return(NULL)
  })
  
  return(parsed_json)
}

# The string needs some cleanup - let's create a function to handle this
clean_json <- function(json_str) {
  L <- read_json(json_str)
  L.content <- L$choices[[1]]$message$content
  # if detect this, this is likely complete
  # can remove inside this and be good to go
  pattern1 <- "(?s)```.*?```"  # (?s) enables dot to match newlines
  if(str_detect(L.content,pattern1)){
    result <- str_extract(L.content, pattern1)
    result <- str_remove_all(result,'```')
    result <- str_remove(result,'^json')}else{
      result <- gsub('^.*?json','',L.content)
    }
  return(result)
}

# Read and combine all string files
for (file in json_files) {
  # Read JSON file
  print(file)
  json_data <- tryCatch(clean_json(file),error = function(e) NULL)
  # Add to list
  all_data[[length(all_data) + 1]] <- json_data
}

js_data <- list()

# Read and combine all string files
for (file in json_files) {
  parsed_content <- tryCatch({
    fromJSON(result)
  }, error = function(e) {
    fromJSON(paste0(result, "}"))
  })
  print(result)
  js <- fromJSON(result)
  return(js)
}
  all_data[[length(all_data) + 1]] <- json_data
}

fixed_json <- fix_json(json_str)




parsed_content <- tryCatch({
    fromJSON(result)
  }, error = function(e) {
    fromJSON(paste0(result, "}"))
  })
  print(result)
  js <- fromJSON(result)
  return(js)
}






# Read and combine all JSON files
for (file in json_files) {
  # Read JSON file
  print(file)
  json_data <- clean_and_parse_json(file)
  # Add to list
  all_data[[length(all_data) + 1]] <- json_data
}


  # Alternative 2: Using positive lookbehind and lookahead
  pattern2 <- "(?<=```).*?(?=```)"
  result2 <- str_extract(your_string, pattern2)
  
  # Alternative 3: Capture everything between first and last ```
  pattern3 <- "```([\\s\\S]*?)```"
  result3 <- str_extract(your_string, pattern3)
  
  
  library(stringr)
  library(stringr)
  
  # Using capture group with parentheses
  pattern <- "```(?:json\n)?([\\s\\S]*?)```"
  result <- str_match(your_string, pattern)[,2]
  # Using str_extract with a regex pattern
  pattern <- "(?<=```json\n).*?(?=\n```)"
  # Or alternatively:
  # pattern <- "```json\n(.*?)\n```"
  
  # To use this with your string:
  extracted_json <- str_extract(L.content, pattern)
  extracted_json
library(stringr)

extract_text <- function(text) {
  pattern <- "(?:`{3}).+(?=`{3})"
  matches <- str_extract(text, pattern)
  return(matches)
}

extract_text(L.content[[1]])

grep('(\\`{3}).*(\\`{3})',L.content,value = T)
str_remove(L.content,'^.+\\`{3}')

grepl('```',L.content)
  str_extract(L.content,'\\`{3}.+\\`{3}',)
  L.content
  L.content <- str_remove(L.content, "^.+?(?=```)")


  L.content <- str_remove(L.content,"^.+```")
  L.content <- str_remove_all(L.content,"\\n")
  L.content <- str_remove(L.content,'^.+json')
  L.content <- str_remove(L.content,'^[^\\{]+')
  L.content <- str_remove(L.content,'[^\\}]+$')
  
  parsed_content <- tryCatch({
    fromJSON(L.content)
  }, error = function(e) {
    fromJSON(paste0(L.content, "}"))
  })
  return(L.content)
}

# Read and combine all JSON files
for (file in json_files) {
  # Read JSON file
  print(file)
  json_data <- clean_and_parse_json(file)
  # Add to list
  all_data[[length(all_data) + 1]] <- json_data
}

all_data[[2]]
# Initialize list to store parsed content
parsed_data <- list()

# Extract and parse content from each element
library(data.table)
library(jsonlite)
library(stringr)

  #L.content <- L.content[[1]]$choices[[1]]$message$content
  L.content.chopped <- str_remove(L.content,'[^\\"]+?$')
  L.content.chopped <- str_remove(L.content.chopped,".*```json\\s*")
  L.content.chopped <- str_replace(L.content.chopped,'(^\\{)\\n\\s','\\1')
  str_sub(L.content.chopped,end = 100)
  fromJSON(paste0(L.content.chopped,']','}','}'))
  
  
  fromJSON(paste0('[',L.content.chopped,']'))
  str_sub(L.content.chopped,end = 20)
  
  json <- c("[", toString(sub("}}", "}", L)), "]")
  fromJSON(json)
  
  
json_str
  cleaned
  
  if(!grepl('\\}$',cleaned)){
    cleaned <- str_remove(cleaned,'```?$')
    cleaned <- paste0(str_remove(cleaned,'\\,?$'),'}')
  }
  
  # Parse JSON into R list
  parsed <- fromJSON(cleaned)

  # Flatten nested structures
  flat_list <- list()
  
  # Handle basic fields
  flat_list$eds_number <- parsed$eds_number
  flat_list$date_prepared <- parsed$date_prepared
  
  # Flatten contracts_leases
  for(name in names(parsed$contracts_leases)) {
    flat_list[[paste0("contract_", name)]] <- parsed$contracts_leases[[name]]
  }
  
  # Flatten fiscal information
  flat_list$account_number <- parsed$fiscal_information$account_number
  flat_list$account_name <- parsed$fiscal_information$account_name
  flat_list$total_amount_this_action <- parsed$fiscal_information$total_amount_this_action
  flat_list$new_contract_total <- parsed$fiscal_information$new_contract_total
  
  # Create separate data.table for fiscal years
  fiscal_years_dt <- as.data.table(parsed$fiscal_information$new_total_amount_for_each_fiscal_year)
  
  # Add time period
  flat_list$period_from <- parsed$time_period_covered_in_this_eds$from
  flat_list$period_to <- parsed$time_period_covered_in_this_eds$to
  
  # Add other important fields
  flat_list$method_of_source_selection <- parsed$method_of_source_selection
  flat_list$statutory_authority <- parsed$statutory_authority
  flat_list$description <- parsed$description_of_work_and_justification_for_spending_money
  
  # Vendor information
  flat_list$vendor_id <- parsed$vendor_information$vendor_id
  flat_list$vendor_name <- parsed$vendor_information$vendor_name
  flat_list$vendor_phone <- parsed$vendor_information$telephone
  flat_list$vendor_address <- parsed$vendor_information$address
  
  # Convert to data.table
  main_dt <- as.data.table(flat_list)
  fiscal_years_dt$eds_number <- main_dt$eds_number
  return(
    list(
    main_table = main_dt,
    fiscal_years = fiscal_years_dt
  )
  )
}

library(jsonlite)

result_list <- lapply(seq_along(all_data)[1:10],function(x) {
  print(x)
  x = 2
  json_str <- all_data[[x]]$choices$message$content
  # Use the function
  result <- clean_and_parse_json(json_str)
  result
})

result_list
# Access the results
main_dt <- result$main_table
fiscal_years_dt <- result$fiscal_years




