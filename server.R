server <- function(input, output, session) {

  perm <- function() {
    p <- dfUserPW()$permissions[1]
    if (is.na(p) || length(p) < 1L) 0L else as.integer(p)
  }
  
  rv <- reactiveValues(notif_ids = character(0), submit_n = 1L)
  
  ## Limited Views
  dfUserPW <- reactive({
    validate(need(!is.null(input$usernamedel), "Loading…"))
    if (nchar(input$usernamedel) < 4L) {
      return(data.frame(
        permissions = 0L, email = NA_character_, Name1 = NA_character_,
        stringsAsFactors = FALSE
      ))
    }
    
    conn <- connectCM()
    on.exit(dbDisconnect(conn), add = TRUE)
    
    userid <- input$usernamedel
    
    out <- tryCatch(
      dbGetQuery(conn,
                 "SELECT DISTINCT Name1, email, permissions FROM personnel WHERE BadgeID = ?",
                 params = list(userid)
                 ),
      error = function(e) {
        showNotification(paste("User lookup failed:", e$message), type = "error")
        data.frame(permissions = 0L, email = NA_character_, Name1 = NA_character_, stringsAsFactors = FALSE)
      })
    
    if (nrow(out) < 1L) {
      out <- data.frame(permissions = 0L, email = NA_character_, Name1 = NA_character_, stringsAsFactors = FALSE)
    }
    out
  })
  
  ##
  user_email_safe <- reactive({
    df <- dfUserPW()
    if (!nrow(df) || !"email" %in% names(df)) {
      return(NULL)
    }
    e <- df$email[[1]]
    if (is.na(e) || !nzchar(as.character(e))) NULL else as.character(e)
  })
  
  output$permissionsForm <- reactive({
    p <- perm()
    p %in% c(1L, 3L, 4L)
  })
  
  output$permissions <- reactive({
    perm() > 0L
  })
  
  output$permissionsGenCM <- reactive({
    p <- perm()
    p %in% c(1L, 5L)
  })
  
  output$permissionsGen <- reactive({
    p <- perm()
    p %in% c(1L, 2L, 4L)
  })
  
  output$permissionsGen2 <- reactive({
    p <- perm()
    p %in% c(1L, 2L, 4L, 5L)
  })

outputOptions(output, 'permissionsGen', suspendWhenHidden = FALSE)
outputOptions(output, 'permissionsGen2', suspendWhenHidden = FALSE)
outputOptions(output, 'permissionsGenCM', suspendWhenHidden = FALSE)
outputOptions(output, 'permissions', suspendWhenHidden = FALSE)
outputOptions(output, 'permissionsForm', suspendWhenHidden = FALSE)

###############
    ### DELIVER COMPOUND - Formulations
    dfInventory <- reactive({
      req(input$barcodedel)
      bc <- trimws(input$barcodedel)
      req(nzchar(bc))
        conn <- connectInventory()
        on.exit(dbDisconnect(conn), add = TRUE)
        tryCatch(
          dbGetQuery(conn, inventoryQ2,
                     params = list(input$barcodedel)),
          error = function(e) {
            validate(need(FALSE, paste("Inventory query failed:", e$message)))
          }
        )
    })
    
    
    dfBarcodes <- reactive({
      req(input$formulation)
      conn <- connectFx()
      on.exit(dbDisconnect(conn), add = TRUE)
      
      if(input$formulation == "Registered"){
        validate(need(nrow(dfInventory()) >= 1L, "No Inventory row for this barcode — check the sample barcode"))
        labname = "jackandjill"
        barcode = dfInventory()$REGNUM}else{
        req(input$LabName)
        labname = input$LabName
        barcode = 'SJCH0'}
      tryCatch(
      dbGetQuery(conn, 
        "SELECT DISTINCT B.SJNUM,B.projectID, B.barcodeID, B.setID, B.cm_barcode,
      				F.calculated_powdermg, 
      				P.PI, P.submitted, P.Status, P.Project
			FROM barcodes2 AS B
			INNER JOIN 
			projects3 as P
			ON 
			B.projectID = P.projectID
			INNER JOIN 
			formProj as F
			ON
			B.projectID = F.projectID AND B.SJNUM = F.SJNUM
			WHERE (B.SJNUM = ? OR P.PI = ?) AND P.Status = 'Active'",
        params = list(barcode, labname)),
      error = function(e) {
        showNotification(paste("Project lookup failed:", e$message), type = "error")
        validate(need(FALSE, "Database error"))
      }
      )
    })
    
    dfCMPersonnel <- reactive({
      validate(need(nchar(input$usernamedel) >= 4L, "Enter your badge ID"))
      
      conn <- connectFx()
      on.exit(dbDisconnect(conn), add = TRUE)
      tryCatch(
      dbGetQuery(conn, 
        "SELECT concat(Name1,' ', Name2) as Name, BadgeID FROM personneldb WHERE BadgeID = ?",
        params = list(input$usernamedel)),
      error = function(e) {
        showNotification(paste("Personnel lookup failed:", e$message), type = "error")
        validate(need(FALSE, "Database error"))
      }
      )
    })

    output$testtable <- renderDataTable({
      df <- dfBarcodes() %>% 
        filter(Status == "Active") %>% 
        select(SJNUM, PI, Project, submitted, calculated_powdermg, Status, cm_barcode, projectID, barcodeID) %>% 
        rename(`Expected mg needs` = calculated_powdermg) %>% 
    		arrange(desc(submitted))   
      
      validate(need(nrow(df) > 0L, "No matching active projects — adjust barcode or reach out to FXXXX@xxxx.com"))
      
      datatable(
        df,
        selection = "single",
        class = "cell-border strip hover",
        options = list(dom = "t")
      )
    }, server = TRUE)
    
    output$amtInventory <- renderTable({
      validate(need(nrow(dfInventory()) > 0L, "No Inventory info"))
      dfInventory() %>%
        unite(SJNum, REGNUM, BATCHID, sep = "-") %>%
        select(SJNum, AMOUNT, CONCENTRATION) %>%
        rename(
          `Amount (mg or uL)` = AMOUNT,
          `Concentration (mg/mL)` = CONCENTRATION
        )
    })

  ### submit2 - Delivered (CM)    
    observeEvent(input$submit2, {
      if (length(input$testtable_rows_selected) != 1L) {
        showNotification("Select exactly one row in the table before delivering", type = "warning")
        return(invisible(NULL))
      }
      bd <- if (is.null(input$barcodedel)) "" else input$barcodedel
      if (!nzchar(trimws(bd))) {
        showNotification("Enter a sample barcode", type = "warning")
        return(invisible(NULL))
      }
      if (identical(input$formulation, "Registered")) {
        if (nrow(dfInventory()) < 1L) {
          showNotification("No Inventory data for this barcode", type = "warning")
          return(invisible(NULL))
        }
      } else {
        if (is.null(input$AmountExt) || is.na(input$AmountExt) || input$AmountExt <= 0) {
          showNotification("Enter a positive amount (mg) for custom barcode", type = "warning")
          return(invisible(NULL))
        }
      }
      
        conn <- connectFx()
        on.exit(dbDisconnect(conn), add = TRUE)
        
        batchID <- if (input$formulation == "Registered") {
          dfInventory()$BATCHID[[1]]
        } else {
          0L 
        }
        
        source_table <- dfBarcodes() %>% 
        	filter(Status == "Active") %>% 
        	select(SJNUM, PI, Project, submitted, calculated_powdermg, cm_barcode, projectID, barcodeID) %>% 
        	arrange(desc(submitted)) 
        
        selected_data <- source_table[input$testtable_rows_selected,]
        tryCatch(
          {
        ## write barcodes2
        if(is.na(selected_data$cm_barcode)){
          dbSendQuery(conn,
            "UPDATE barcodes2 SET cm_barcode = ?, batchID = ?, type = 'CM' WHERE barcodeID = ?",
            params = list(input$barcodedel, batchID, selected_data$barcodeID))
          } else {
            dfNew <- tibble(
              SJNUM = selected_data$SJNUM, 
              setID = 1, 
              cm_barcode = input$barcodedel,
        			projectID = selected_data$projectID, 
        			batchID = batchID, 
        			type = "CM")
        		dbWriteTable(conn,"barcodes2", dfNew, append=TRUE, row.names = FALSE)
        		}
        
        ## write cmpdlocal
       dfID <- dbGetQuery(conn, 
                          "SELECT barcodeID FROM barcodes2 WHERE cm_barcode = ? and projectID = ?",
                          params = list(input$barcodedel, selected_data$projectID)) 
       if (nrow(dfID) < 1L) stop("Could not resolve barcode ID after update")
       
       df <- tibble(barcode1 = dfID$barcodeID, 
                    BadgeID = input$usernamedel,
                    scanDate = Sys.Date(), 
                    date_time = Sys.time(),
                    cmpdaction = "Delivered", 
                    
       )
       
       if(input$formulation == "Registered"){
         if(dfInventory()$ISDRY == 1){
           df1 <- df %>% mutate(amountmg = dfInventory()$AMOUNT)
            } else {
           df1 <- df %>% mutate(amountul = dfInventory()$AMOUNT)
       	}
         } else {
        	df1 <- df %>% mutate(amountmg = input$AmountExt)
       	}
       
       
      dbWriteTable(conn,"cmpdlocal", df1, append=TRUE, row.names = FALSE)
          },
      error = function(e) {
        showNotification(paste("Save failed:", e$message), type = "error")
        return(invisible(NULL))
      }
        )
      
      ## shinyjs submits
      shinyjs::hide("submit2")
      shinyjs::show("submitmsg2")
      shinyjs::reset("barcodedel")
      shinyjs::reset("AmountExt")
        
      nm <- tryCatch(
        dfCMPersonnel()$Name[[1]], error = function(e) "Unknown user")
      
    tryCatch(
      mailFxn(
        c("KXXXX@xxxx.com", user_email_safe()), 
        "Compound Delivered to ATC Fridge", 
              paste("Vial", input$barcodedel, "of compound", selected_data$SJNUM, 
                    "was delivered to the ATC fridge by", nm, "on", format(Sys.time()),"."
                    )
        ),
      error = function(e) showNotification(paste("Email not sent:", e$message), type = "warning")
      )
      
    }) ## end submit2
    
    observeEvent(input$addanother2, {
      shinyjs::show("submit2")
      shinyjs::hide("submitmsg2")

    })
    
    ### End submit2
    
  ##### submit3 - Received(ATC)  
    observeEvent(input$submit3, {
      if (length(input$testtable_rows_selected) != 1L) {
        showNotification("Select exactly one row before recording receipt", type = "warning")
        return(invisible(NULL))
      }
      
      source_table <- dfBarcodes() %>% 
        filter(Status == "Active") %>%
        select(SJNUM, PI, Project, submitted, calculated_powdermg,cm_barcode, projectID, barcodeID) %>% 
        arrange(desc(submitted)) 
          
      selected_data <- source_table[input$testtable_rows_selected,]
      
      if (nrow(selected_data) != 1L) {
        showNotification("Invalid row selection", type = "warning")
        return(invisible(NULL))
      }
      
      conn <- connectFx()
      on.exit(dbDisconnect(conn), add = TRUE)
      
      dfSQL <-  tryCatch(
        dbGetQuery(conn, 
        "SELECT B.barcodeID, B.cm_barcode, B.SJNUM,
  		L.amountmg, L.amountul
      FROM barcodes2 AS B
			INNER JOIN cmpdlocal as L
			ON B.barcodeID = L.barcode1
			WHERE L.cmpdaction = 'Delivered' AND B.barcodeID = ?",
			params = list(selected_data$barcodeID)),  
			error = function(e) {
			  showNotification(paste("Lookup failed:", e$message), type = "error")
			  return(NULL)
			}
      )
      
      if (is.null(dfSQL) || nrow(dfSQL) < 1L) {
        showNotification("No prior “Delivered” record for this barcode — deliver first (CM)", type = "warning")
        return(invisible(NULL))
      }
      
        df <- dfSQL %>% 
          mutate(setID = 01, 
                 BadgeID = input$usernamedel, 
                 scanDate = Sys.Date(),
                 date_time = Sys.time(), 
                 cmpdaction = "Received") %>% 
        distinct() %>% 
        as.data.frame() %>% 
        select(barcodeID, BadgeID, scanDate, date_time, cmpdaction, amountmg, amountul) %>% 
        rename(barcode1 = barcodeID) 
        
        tryCatch(
      dbWriteTable(conn,"cmpdlocal", df, append=TRUE, row.names = FALSE),
      error = function(e) {
        showNotification(paste("Save failed:", e$message), type = "error")
        return(invisible(NULL))
      }
        )
        
      shinyjs::hide("submit3")
      shinyjs::show("submitmsg3")
      shinyjs::reset("barcodedel")
      shinyjs::reset("AmountExt")

    })
    
    observeEvent(input$addanother3, {
      shinyjs::show("submit3")
      shinyjs::hide("submitmsg3")

    })
    
    observeEvent(input$addanother6, {
    	updateTextInput(session, "usernamedel", value = "")
    	updateTextInput(session, "barcodedel", value = "")
    	updateTextInput(session, "AmountExt", value = "")
    	updateTextInput(session, "LabName", value = "")
    	ids <- rv$notif_ids
    	if (length(ids) > 0L) {
    	  removeNotification(ids[[1]])
    	  rv$notif_ids <- if (length(ids) > 1L) ids[-1L] else character(0)
    	}
    })
    
    
    output$LabName <-renderUI({
    	selectInput("LabName", "PI (last name, first name)", choices=get_data())
    })
    
    
 #############################################################   
  ### CM General Compound Procurement
    ## Delivery barcodes
dfCM <- reactive({
  d1 <- data.frame(cmbarcode = input$cmCmpds, 
             userBadge = input$usernamedel, 
             barcode_type = input$genType,
             scanDate = Sys.Date(),
             scanTime = Sys.time())
  d1 %>% 
    separate_longer_delim(cmbarcode, delim="\n") %>% 
    mutate(cmbarcode = trimws(cmbarcode)) %>%
    filter(cmbarcode != "")
  })
  

output$numplates <- renderUI({
  req(input$genType)
    if (!identical(input$genType, "Delivery")) {
      return(NULL)
    }
    dfc <- dfCM()
    codes <- unique(dfc$cmbarcode)
    codes <- codes[nzchar(codes)]
    if (length(codes) < 1L) {
      return(tags$p(class = "text-muted", "Enter delivery barcodes to see plate counts"))
    }
    
      conn <- connectCM()
      on.exit(dbDisconnect(conn), add = TRUE)
      res <- tryCatch(dbGetQuery(conn, "SELECT num_plates from delivery_barcodes where del_barcode in(?)",
                        params = list(codes)),
                      error = function(e) NULL)
      if (is.null(res) || nrow(res) < 1L) {
        return(tags$p(class = "text-warning", "No plate count found for these barcodes"))
      }
      txt <- paste(stats::na.omit(unique(res$num_plates)), collapse = ", ")
      tags$div(tags$strong("Plate count(s): "), txt)
                      
    })

## Chem track function
chemtrackFxn <- function(action, notif_label, mail_subject, mail_body_fn) {
  df <- dfCM() %>% mutate(cmpdAction = action)
  if (nrow(df) < 1L) {
    showNotification("Enter at least one barcode (one per line).", type = "warning")
    return(invisible(FALSE))
  }
  barcode_text <- paste(df$cmbarcode, collapse = "\n")
  conn <- connectCM()
  on.exit(dbDisconnect(conn), add = TRUE)
  ok <- tryCatch(
    {
      dbWriteTable(conn, "chem_track", df, append = TRUE, row.names = FALSE)
      TRUE
    },
    error = function(e) {
      showNotification(paste("Database error:", e$message), type = "error")
      FALSE
    }
  )
  if (!ok) {
    return(invisible(FALSE))
  }
  updateTextInput(session, "cmCmpds", value = "")
  nid <- showNotification(notif_label, type = "message", duration = 5)
  rv$notif_ids <- c(rv$notif_ids, nid)
  rv$submit_n <- rv$submit_n + 1L
  ue <- user_email_safe()
  nm <- tryCatch(dfCMPersonnel()$Name[[1]], error = function(e) "Unknown user")
    tryCatch(
      mailFxn(ue, mail_subject, mail_body_fn(nm, barcode_text)),
      error = function(e) showNotification(paste("Email not sent:", e$message), type = "warning")
    )
  invisible(TRUE)
}

    
observeEvent(input$received, { ## removed from fridge
  ok <- chemtrackFxn(
    "Received",
    paste0("Recorded pickup (", rv$submit_n, ")"),
    "Compounds picked up from E9073B Fridge",
    function(nm, barcode_text) {
      paste0(
        "The listed items were picked up from E9073B by ", nm, " on ", format(Sys.time()), ".\n",
        barcode_text
      )
    }
  )
  if (!ok) {
    return(invisible(NULL))
  }
  

  # 
  shinyjs::hide("received")
  shinyjs::show("submitmsg4")
  shinyjs::show("addanother4")
  })

observeEvent(input$addanother4,{
  shinyjs::hide("submitmsg4")
  shinyjs::hide("addanother4")
  shinyjs::show("received")
  shinyjs::reset("cmCmpds")
  
})

observeEvent(input$returned, { ## delivered to fridge
  
  ok <- chemtrackFxn(
    "Returned",
    paste0("Recorded return (", rv$submit_n, ")"),
    "Compounds returned to EXXXXB Fridge",
    function(nm, barcode_text) {
      paste0(
        "The listed items were returned to EXXXXB by ", nm, " on ", format(Sys.time()), ".\n",
        barcode_text
      )
    }
  )
  if (!ok) {
    return(invisible(NULL))
  }
  
  shinyjs::hide("returned")
  shinyjs::show("submitmsg5")
  shinyjs::show("addanother5")
})

observeEvent(input$addanother5,{
  shinyjs::hide("submitmsg5")
  shinyjs::hide("addanother5")
  shinyjs::show("returned")
  shinyjs::reset("cmCmpds")
  
})

observeEvent(input$deliveredcm, { ## delivered by CM
  
  ok <- chemtrackFxn(
    "Delivered",
    paste0("Recorded CM delivery (", rv$submit_n, ")"),
    "Compounds delivered by CM to EXXXXB Fridge",
    function(nm, barcode_text) {
      paste0(
        "The listed items were delivered to EXXXXB by ", nm, " on ", format(Sys.time()), ".\n",
        barcode_text
      )
    }
  )
  if (!ok) {
    return(invisible(NULL))
  }
  

  shinyjs::hide("deliveredcm")
  shinyjs::show("submitmsg6.1")
  shinyjs::show("addanother6.1")
})

observeEvent(input$addanother6.1,{
  shinyjs::hide("submitmsg6.1")
  shinyjs::hide("addanother6.1")
  shinyjs::show("deliveredcm")
  shinyjs::reset("cmCmpds")
})

observeEvent(input$returnedcm, { ## removed from fridge by CM
  
  ok <- chemtrackFxn(
    "Return Received",
    paste0("Recorded CM pickup (", rv$submit_n, ")"),
    "Compound return received by CM",
    function(nm, barcode_text) {
      paste0(
        "The listed items were picked up from EXXXXB by ", nm, " on ", format(Sys.time()), ".\n",
        barcode_text
      )
    }
  )
  if (!ok) {
    return(invisible(NULL))
  }
  
  shinyjs::hide("returnedcm")
  shinyjs::show("submitmsg7")
  shinyjs::show("addanother7")

})

observeEvent(input$addanother7,{
  shinyjs::hide("submitmsg7")
  shinyjs::hide("addanother7")
  shinyjs::show("returnedcm")
  shinyjs::reset("cmCmpds")
  
})

observeEvent(input$cleardata,{
  shinyjs::reset("usernamedel")
  shinyjs::reset("cmCmpds")
  
})

}