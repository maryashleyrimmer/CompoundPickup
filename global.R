library(shiny)
library(DBI)
library(tidyverse)
library(dbplyr)
library(DT)
library(sendmailR)
library(shinyjs)
library(RMariaDB)
library(odbc)
library(bslib)
library(shinythemes)
library(fontawesome)


qr_app <- file.path("../../prep-queries-root.R")
qr_sys <- "/usr/local/prep-queries-root.R"
if (file.exists(qr_sys)) {
  source(qr_sys, local = TRUE)
} else if (file.exists(qr_app)) {
  source(qr_app, local = TRUE)
} else {
  stop("prep-queries-root.R not found (expected in /usr/local/ or the app directory).", call. = FALSE)
}



mailFxn <- function(user_email, subject, msg) {
  team <- c(
    "MXXXXX@xxxx.com",
    "MXXXXX@xxxx.com",
    "MXXXXX@xxx.com",
  )
  to <- c(user_email, team)
  to <- unique(to[!is.na(to) & nzchar(as.character(to))])
  if (length(to) < 1L) {
    warning("mailFxn: no recipients; skipping send.")
    return(invisible(NULL))
  }
  sendmail(
    from = "CompoundTrackingApp@xxx.xxx",
    to = to,
    subject = subject,
    msg = mime_part(paste(msg)),
    control = list(smtpServer = "smtp.xxxx.xxx", verbose = FALSE)
  )
}
