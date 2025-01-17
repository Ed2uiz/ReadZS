#!/usr/bin/env Rscript

library(data.table)


args<-commandArgs(TRUE)
input_file <- args[1]  # input file
basename <- args[2] # basename of the output file
libType <- args[3] # 10X or SS2
binSize <- as.numeric(args[4]) # bin size

## Function to get bin from position, strand, and chromsome
get_bin <- function(pos, binSize, chr, strand, libraryType) 
{
  pos <- as.numeric(pos)
  bin_num <- ceiling(pos/binSize)
  if (libraryType == "10X") {
    bin <- paste(chr, bin_num, strand, sep="_")
  } else if (libraryType == "SS2") {
    bin <- paste(chr, bin_num, sep="_")
  }
  return(bin)
}

## Determine the strand of the data
get_strand <- function(strand_col) # strand_col is a vector of strand labels
{
  if (unique(strand_col) == "+")  # if all reads are on the same strand, return that strand
  {
    strand_label <- "plus"
  } else if (unique(strand_col) == "-")
  {
    strand_label <- "minus"
  }
}

## Read in filter output
data <- fread(input_file, header = FALSE)
if (nrow(data) > 0) {  # if the input file is empty, don't do any of this.
  if (libType == '10X')
  {
    names(data) <- c('barcode', 'umi', 'strand','chr', 'pos', 'channel')

    # Get the strand label for the bin
    strand_label <- get_strand(data$strand)

    ## Deduplication step 1: deal with reads that have the same BC and UMI but different positions
    data[, numDiffPos := uniqueN(pos), by=c("barcode", "umi", "channel")]
    data[, pos := ifelse(numDiffPos > 1, mean(pos), pos), by=list(barcode, umi, channel)]
    # when there's more than one position for a BC + UMI pair, assigned position is average position

    ## Deduplication step 2: collapse reads with same BC, UMI, and position
    data <- unique(data[, list(chr, strand, pos, barcode, umi, channel)])

    ## Find total count of reads at each position, by channel and cell
    data <- data[, count := .N, by=.(pos, barcode, channel)]
    data <- data[,c("strand","chr","pos","barcode","count","channel")]
    data <- unique(data)

    ## Add column for cell id: paste channel and cell barcode
    data$cell_id <- paste(data$channel, data$barcode, sep = "_")
    data <- data[, c("cell_id", "chr", "pos", "strand", "count","channel")]

    ## Create bin from position
    data <- data[, bin := get_bin(pos, binSize, chr, strand_label, libType)]

    ## Output
    output_file_name <- paste(basename, ".count", sep="")
    write.table(data, output_file_name, col.names=TRUE, row.names=FALSE, sep = "\t", quote=FALSE)

  } else if (libType == "SS2")
  {
    names(data) <- c('cell_id', 'strand', 'chr', 'pos', 'channel')

    # Get counts at each position
    data <- data[, count := .N, by=.(pos, cell_id, channel, strand)] #
    data <- data[, c("cell_id", "chr", "pos", "strand", "count", "channel")]

    # TODO: remove this line
    # write.table(data, "data_temp.count", col.names=TRUE, row.names=FALSE, sep = "\t", quote=FALSE)

    # TODO: figure out why get_strand was returning + and -
    # Get the strand label for the bin
    # strand_label <- get_strand(data$strand)
    strand_label <- "plus"

    ## Create bin from position
    data <- data[, bin := get_bin(pos, binSize, chr, strand_label, libType)]

    ## Replace strand_label with NA to indicate that the strand column doesn't convey actual strand info
    data[, strand := NA]

    #TODO: delete this with changes to filter.py:get_read_info()
    ## Add 'chr' prefix to chr column only if it is missing
    # if(!grepl("chr", data$chr[1])) data[, chr := paste0("chr", data$chr)]

    ## Output
    output_file_name <- paste(basename, ".count", sep="")
    write.table(data, output_file_name, col.names=FALSE, row.names=FALSE, sep = "\t", quote=FALSE)
  }
}
