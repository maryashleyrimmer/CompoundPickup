formulation_database <- "xxxx"
formulation_username <- "xxxx"
formulation_password <- "xxxx"
formulation_hostName <- "xxxxx"

cm_database <- "xxxx"
cm_username <- "xxxx"
cm_password <- "xxxx"
cm_hostName <- "xxxxx"

inventory_user <- "xxxx"
inventory_password <- "xxxx"
invetory_connection <- "xxxx"
inventory_db <- "XXXX2"

connectFx <- function(){
  conn <- dbConnect(
    drv = RMariaDB::MariaDB(),
    host = formulation_hostName,
    dbname = formulation_database,
    username = formulation_username,
    password = formulation_password
  )
  return(conn)
}

connectCM <- function(){
  conn <- dbConnect(
    drv = RMariaDB::MariaDB(),
    host = cm_hostName,
    dbname = cm_database,
    username = cm_username,
    password = cm_password
  )
  return(conn)
}

connectInventory <- function(){
  conn <- DBI::dbConnect(odbc::odbc(),
                         Driver = "Oracle",
                         Host   = inventory_connection,
                         SVC    = inventory_db,
                         UID    = inventory_user,
                         PWD    = inventory_password,
                         Port   = 1521
  )
  return(conn)
}

get_data <- function(){
  conn <- connectFx()
  on.exit(dbDisconnect(conn), add = TRUE)
  q <-"SELECT distinct PI FROM projects3 WHERE Status = 'Active';" 
  return(dbGetQuery(conn, q))
}

inventoryQ2 <- "SELECT
	MOSAIC.INV_LABWARE_ITEM.LABWAREBARCODE,
	MOSAIC.INV_COMPOUND_HOLDER.AMOUNT,
	MOSAIC.INV_COMPOUND_HOLDER.CONCENTRATION,
	MOSAIC.INV_COMPOUND_HOLDER.ISDRY,
	MOSAIC.VW_INVTI_COMPOUND_FULL.NAMEPART0 RegNum,
	MOSAIC.VW_INVTI_COMPOUND_FULL.NAMEPART1 BatchId
from
	MOSAIC.INV_LABWARE_ITEM,
	MOSAIC.INV_COMPOUND_HOLDER,
	MOSAIC.VW_INVTI_COMPOUND_FULL
where
	MOSAIC.INV_COMPOUND_HOLDER.LABWAREITEMID = MOSAIC.INV_LABWARE_ITEM.LABWAREITEMID
AND
	MOSAIC.INV_COMPOUND_HOLDER.COMPOUNDID IS NOT NULL
AND
	MOSAIC.INV_LABWARE_ITEM.LABWARECLASSID = '4'
AND
	MOSAIC.VW_INVTI_COMPOUND_FULL.COMPOUNDID = MOSAIC.INV_COMPOUND_HOLDER.COMPOUNDID
AND
	MOSAIC.INV_LABWARE_ITEM.LABWAREBARCODE = ?"

