navbarPage(title = div(img(src="compoundtrail-crop.png", width = "45%")), 
           theme = shinytheme("journal"), 
  useShinyjs(),
  
  card(full_screen = TRUE, 
   layout_sidebar(
     sidebar=sidebar(
       
       textInput("usernamedel",h4("User Badge ID")),
       conditionalPanel(condition = "output.permissions",
          
          actionButton("addanother6",h4("Finish (lock app)",fa(name = "lock")),
                    class="btn btn-primary"
       )),
      
      div(align = "center", img(src="ACC.png", width = "33%"),
           img(src="CM.png", width = "33%")
           )
      ),
    navset_card_tab(full_screen = TRUE,
         nav_panel("General Delivery/Pickup",
                   page_fillable(
                                    layout_columns(
                                
                                      conditionalPanel(condition = "output.permissionsGen",
                                                       
                                      card(
                                        selectInput("genType", h5("Barcode Type"), choices = list("Registered","Custom", "Delivery")),
                                        
                                        textAreaInput("cmCmpds", "Sample Barcode(s)", height = "250px"),
                                        card(uiOutput("numplates")),
                                        ) 
                                      ),
                                      conditionalPanel(condition = "output.permissionsGen",
                                                       
                                      ## column 2 - general delivery/pickup
                                      card(
                                        h4("Compound Transfer", align = "center"),
                                      actionButton("received", "Removed from fridge", class = "btn btn-info"),
                                      hidden(
                                        div(id = "submitmsg4", "Submitted",
                                            actionButton("addanother4","Submit another", class = "btn btn-secondary"))
                                                       ),## close hidden
                                      br(),
                                      actionButton("returned", "Delivered to fridge", class = "btn btn-info"),
                                      hidden(
                                        div(id = "submitmsg5", "Submitted",
                                             actionButton("addanother5","Submit another",class = "btn btn-secondary"))
                                                       )  ## close hidden

                                               
                                                  )## close column 2 card
                                      ), ## close conditional panel
                                      conditionalPanel(condition = "output.permissionsGenCM",
                                     card(
                                       h4("Compound Delivery (CM)", align = "center"),
                                     actionButton("deliveredcm", "Delivered to fridge by CM", class = "btn btn-info"),
                                     hidden(
                                       div(id = "submitmsg6.1", "Submitted",
                                           actionButton("addanother6.1","Submit another", class = "btn btn-secondary"))
                                                     ),## close hidden
                                    br(),
                                    actionButton("returnedcm", "Removed from fridge by CM",class = "btn btn-info"),
                                    hidden(
                                      div(id = "submitmsg7", "Submitted",
                                          actionButton("addanother7","Submit another",class = "btn btn-secondary"))
                                                       )## close hidden
                                                  ),## Close column 3 card
                                                ),## close conditional Panel
                                    col_widths=c(4,4,4)
                               )## close layout columns
                   
         )## close nav panel
         ), ## close page fillable
          nav_panel("Formulations Compounds",
                    conditionalPanel(condition = "output.permissionsForm",
                                     
                 br(),
                 layout_column_wrap(
                   width = 1/2,
                 card(
                   textInput("barcodedel", h5("Sample Barcode", fa(name = "barcode"))),
                   
                 actionButton("submit2", "Delivered", class = "btn btn-info"),
                 hidden(
                   div(id = "submitmsg2", "Submitted",
                     actionLink("addanother2","Submit another"))
                 ),
                 hr(),
                 actionButton("submit3", "Received (ATC)", class = "btn btn-info"),
                 hidden(
                   div(id = "submitmsg3", "Submitted",
                     actionLink("addanother3", "Submit another"))
                 ),
                 ),
                 
               card(align = "center",
                    selectInput("formulation", h5("Registerd or Custom Barcode"), choices = list("Registered","Custom")),
                    
                        conditionalPanel(condition = "input.formulation == 'Registered'",
                        h5("Inventory Info", align = "center"),
                                         tableOutput("amtInventory")),
                        conditionalPanel(condition = "input.formulation == 'Custom'",
                                         uiOutput("LabName"),
                                         numericInput("AmountExt","Amount (mg)",0)))## Close card
               ), ## close columns
                 card(
                 br(),
                 dataTableOutput("testtable"))))
    

    )
))
)

                
