# =============================================================================
# sow_transform.R
#
# PURPOSE: Generate sentence-level embeddings for description_of_work text
#          from EDS contract extraction results.
#
# WHY SENTENCE-LEVEL: Embedding at the sentence level (rather than full
#          description) preserves granularity. This allows downstream analysis
#          to compute various aggregations:
#            - Mean embedding (central tendency of the description)
#            - Std/variance (semantic diversity within description)
#            - Pairwise distances (internal coherence)
#            - Clustering (identify distinct themes)
#
# INPUTS:  eds_claude_extraction_results.csv
#            - Contains extracted contract data including description_of_work
#            - Each row is one contract document (original or amendment)
#
# OUTPUTS:
#   1. sow_sentence_metadata.csv
#        - Links sentences back to source documents
#        - Contains: doc_row_id, contract_id, amendment_num, sentence_idx, etc.
#        - Does NOT contain embeddings (for easy inspection)
#
#   2. sow_sentence_embeddings.parquet
#        - Contains sentence text + 768-dimensional embedding vectors
#        - Parquet format for efficient storage and fast loading
#        - Join with metadata using doc_row_id + sentence_idx
#
# REQUIREMENTS:
#   R packages: tidyverse, reticulate, here
#   Python packages: sentence-transformers, nltk, pyarrow, pandas, numpy
#
# =============================================================================

library(tidyverse)
library(reticulate)

# =============================================================================
# CONFIGURATION
# =============================================================================

# Hugging Face model for generating embeddings
# all-mpnet-base-v2: 768-dim embeddings, 512 token max, strong semantic similarity
# See: https://huggingface.co/sentence-transformers/all-mpnet-base-v2
MODEL_NAME <- "sentence-transformers/all-mpnet-base-v2"

# File paths (using here::here for project-relative paths)
INPUT_CSV <- here::here("data/intermediate_products/eds_claude_extraction_results.csv")
OUTPUT_EMBEDDINGS <- here::here("data/intermediate_products/sow_sentence_embeddings.parquet")
OUTPUT_METADATA <- here::here("data/intermediate_products/sow_sentence_metadata.csv")

# Number of sentences to embed at once
# Higher = faster but more memory; lower = slower but safer for limited RAM
BATCH_SIZE <- 128

# =============================================================================
# PYTHON ENVIRONMENT SETUP
# =============================================================================

# If you need to use a specific Python environment, uncomment one of these:
# use_condaenv("your_env_name")
# use_virtualenv("your_venv_path")

# Import required Python libraries via reticulate
# sentence_transformers: Hugging Face library for text embeddings
# nltk: Natural Language Toolkit for sentence tokenization
st <- import("sentence_transformers")
nltk <- import("nltk")

# NLTK requires the 'punkt' tokenizer data for sentence splitting
# These tryCatch blocks download it if not already present
tryCatch({
  nltk$data$find("tokenizers/punkt")
}, error = function(e) {
  nltk$download("punkt")
})

tryCatch({
  nltk$data$find("tokenizers/punkt_tab")
}, error = function(e) {
  nltk$download("punkt_tab")
})

# Load the transformer model (this may take a moment on first run as it downloads)
cat("Loading model:", MODEL_NAME, "\n")
model <- st$SentenceTransformer(MODEL_NAME)
cat("Model loaded successfully\n")

# =============================================================================
# LOAD AND PREPARE DATA
# =============================================================================

cat("Loading input data...\n")
df <- read_csv(INPUT_CSV, show_col_types = FALSE)
cat("Total rows:", nrow(df), "\n")

# Prepare the working dataframe with:
#   - doc_row_id: unique identifier for each row (for joining back later)
#   - contract_id: extracted from filename (e.g., "6643" from "6643-002.pdf")
#   - amendment_num: extracted from filename (e.g., "002" from "6643-002.pdf")
#                    "000" typically = original contract, "001"+ = amendments
#   - Key metadata fields for downstream analysis
df_work <- df %>%
  mutate(
    # Assign a unique row ID for joining embeddings back to source data
    doc_row_id = row_number(),

    # Parse the source filename to extract contract tracking info
    # Example filename: "6643-002.pdf" -> contract_id="6643", amendment_num="002"
    contract_file = basename(metadata_source_file),
    contract_id = str_extract(contract_file, "^[^-]+(?:-[^-]+)?(?=-\\d{3}\\.pdf$)"),
    amendment_num = str_extract(contract_file, "(?<=-)(\\d{3})(?=\\.pdf$)")
  ) %>%
  # Select only the columns needed for embedding + analysis
  select(
    doc_row_id,
    contract_file,
    contract_id,
    amendment_num,
    eds_number,
    vendor_name,
    agency_name,
    date_prepared,
    time_period_from,
    time_period_to,
    description_of_work
  ) %>%
  # Remove rows without description text (nothing to embed)
  filter(!is.na(description_of_work) & description_of_work != "")

cat("Documents with descriptions:", nrow(df_work), "\n")

# =============================================================================
# SENTENCE TOKENIZATION
# =============================================================================
# Split each description_of_work into individual sentences.
# This is the key step that enables granular embedding.
#
# NLTK's sent_tokenize handles:
#   - Period/question mark/exclamation boundaries
#   - Abbreviations (Dr., Mr., U.S., etc.)
#   - Decimal numbers (3.14 doesn't split)
# =============================================================================

cat("Tokenizing descriptions into sentences...\n")

# Helper function: split a single text into sentences
# Returns empty character vector if text is NA or empty
split_sentences <- function(text) {
  if (is.na(text) || text == "") {
    return(character(0))
  }
  nltk$tokenize$sent_tokenize(text)
}

# Pre-allocate list for efficiency (one slot per document)
sentences_list <- vector("list", nrow(df_work))

# Loop through each document and tokenize into sentences
# Each sentence gets its own row with full metadata
for (i in seq_len(nrow(df_work))) {
  # Progress logging every 1000 documents
  if (i %% 1000 == 0) {
    cat("Processing document", i, "of", nrow(df_work), "\n")
  }

  doc <- df_work[i, ]
  sents <- split_sentences(doc$description_of_work)

  if (length(sents) > 0) {
    # Create a tibble with one row per sentence
    # Carries forward all document metadata for easy joins
    sentences_list[[i]] <- tibble(
      # Document identifiers (for joining back to source)
      doc_row_id = doc$doc_row_id,
      contract_file = doc$contract_file,
      contract_id = doc$contract_id,
      amendment_num = doc$amendment_num,
      eds_number = doc$eds_number,

      # Context metadata (for analysis)
      vendor_name = doc$vendor_name,
      agency_name = doc$agency_name,
      date_prepared = doc$date_prepared,
      time_period_from = doc$time_period_from,
      time_period_to = doc$time_period_to,

      # Sentence-specific fields
      sentence_idx = seq_along(sents),     # Position within document (1, 2, 3...)
      sentence_count = length(sents),       # Total sentences in this document
      sentence_text = sents                 # The actual sentence text
    )
  }
}

# Combine all sentence tibbles into one dataframe
sentences_df <- bind_rows(sentences_list)

cat("Total sentences:", nrow(sentences_df), "\n")
cat("Average sentences per document:", round(mean(sentences_df$sentence_count), 2), "\n")

# =============================================================================
# GENERATE EMBEDDINGS
# =============================================================================
# Use the sentence-transformer model to convert each sentence into a
# 768-dimensional vector. These vectors capture semantic meaning:
#   - Similar sentences -> vectors close together (high cosine similarity)
#   - Different sentences -> vectors far apart (low cosine similarity)
#
# Batching is used to balance speed vs memory usage.
# =============================================================================

cat("Generating embeddings...\n")

# Extract just the sentence texts for embedding
all_sentences <- sentences_df$sentence_text

# Calculate batch parameters
n_sentences <- length(all_sentences)
n_batches <- ceiling(n_sentences / BATCH_SIZE)

# Pre-allocate list for batch results
embeddings_list <- vector("list", n_batches)

# Process sentences in batches
for (batch_idx in seq_len(n_batches)) {
  # Calculate which sentences are in this batch
  start_idx <- (batch_idx - 1) * BATCH_SIZE + 1
  end_idx <- min(batch_idx * BATCH_SIZE, n_sentences)

  batch_texts <- all_sentences[start_idx:end_idx]

  cat("Embedding batch", batch_idx, "of", n_batches,
      "(sentences", start_idx, "-", end_idx, ")\n")

  # Call the model to generate embeddings
  # Returns a numpy array of shape (batch_size, 768)
  batch_embeddings <- model$encode(
    batch_texts,
    convert_to_numpy = TRUE,    # Return as numpy array (not torch tensor)
    show_progress_bar = FALSE   # We're showing our own progress
  )

  embeddings_list[[batch_idx]] <- batch_embeddings
}

# Stack all batches into a single numpy array
cat("Combining embeddings...\n")
np <- import("numpy")
all_embeddings <- np$vstack(embeddings_list)

cat("Embedding matrix shape:", dim(all_embeddings)[1], "x", dim(all_embeddings)[2], "\n")

# =============================================================================
# SAVE OUTPUTS
# =============================================================================
# Two output files are created:
#
# 1. METADATA CSV: Easy to inspect, small file size
#    - All document/sentence metadata WITHOUT the embedding vectors
#    - Use for quick lookups, filtering, and joining
#
# 2. EMBEDDINGS PARQUET: Efficient storage for large numeric data
#    - Contains: sentence_id, doc_row_id, sentence_idx, sentence_text, emb_000...emb_767
#    - Parquet is columnar and compressed, ideal for large numeric arrays
#    - Can be loaded in R (arrow package) or Python (pandas/pyarrow)
# =============================================================================

cat("Saving outputs...\n")

# --- Save metadata CSV ---
# Excludes sentence_text since it's in the parquet file
sentences_df %>%
  select(-sentence_text) %>%
  write_csv(OUTPUT_METADATA)

cat("Metadata saved to:", OUTPUT_METADATA, "\n")

# --- Save embeddings parquet ---
# Using Python's pyarrow via reticulate for parquet writing
arrow <- import("pyarrow")
pq <- import("pyarrow.parquet")
pa <- import("pandas")

# Create column names for the 768 embedding dimensions: emb_000, emb_001, ..., emb_767
embedding_dim <- dim(all_embeddings)[2]
col_names <- paste0("emb_", sprintf("%03d", seq_len(embedding_dim) - 1))

# Build pandas DataFrame with embeddings as columns
embeddings_py_df <- pa$DataFrame(all_embeddings, columns = col_names)

# Add identifier columns for joining
embeddings_py_df["sentence_id"] <- seq_len(nrow(sentences_df)) - 1L  # 0-indexed for Python compatibility
embeddings_py_df["doc_row_id"] <- sentences_df$doc_row_id
embeddings_py_df["sentence_idx"] <- sentences_df$sentence_idx
embeddings_py_df["sentence_text"] <- sentences_df$sentence_text

# Reorder so identifiers come first, then embedding dimensions
id_cols <- c("sentence_id", "doc_row_id", "sentence_idx", "sentence_text")
all_cols <- c(id_cols, col_names)
embeddings_py_df <- embeddings_py_df[all_cols]

# Write to parquet format
table <- arrow$Table$from_pandas(embeddings_py_df)
pq$write_table(table, OUTPUT_EMBEDDINGS)

cat("Embeddings saved to:", OUTPUT_EMBEDDINGS, "\n")

# =============================================================================
# SUMMARY
# =============================================================================

cat("\n")
cat("=== PROCESSING COMPLETE ===\n")
cat("Documents processed:", nrow(df_work), "\n")
cat("Sentences embedded:", nrow(sentences_df), "\n")
cat("Embedding dimensions:", embedding_dim, "\n")
cat("Model used:", MODEL_NAME, "\n")
cat("\n")
cat("Output files:\n")
cat("  Metadata:", OUTPUT_METADATA, "\n")
cat("  Embeddings:", OUTPUT_EMBEDDINGS, "\n")
cat("\n")
cat("--- Loading embeddings later ---\n")
cat("\n")
cat("In R:\n")
cat("  library(arrow)\n")
cat("  embeddings <- read_parquet('", OUTPUT_EMBEDDINGS, "')\n", sep = "")
cat("  metadata <- read_csv('", OUTPUT_METADATA, "')\n", sep = "")
cat("\n")
cat("In Python:\n")
cat("  import pandas as pd\n")
cat("  embeddings = pd.read_parquet('", OUTPUT_EMBEDDINGS, "')\n", sep = "")
cat("  metadata = pd.read_csv('", OUTPUT_METADATA, "')\n", sep = "")
cat("\n")
cat("--- Example downstream analysis ---\n")
cat("\n")
cat("# Compute mean embedding per document (central tendency):\n")
cat("#   embeddings %>% group_by(doc_row_id) %>% summarise(across(starts_with('emb_'), mean))\n")
cat("\n")
cat("# Compute std per document (semantic variance):\n")
cat("#   embeddings %>% group_by(doc_row_id) %>% summarise(across(starts_with('emb_'), sd))\n")
