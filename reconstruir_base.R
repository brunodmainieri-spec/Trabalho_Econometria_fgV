# Etapa opcional. Reconstrói a base municipal integrada em reconstruidos/.
# Requer data.table, jsonlite e pdftools. Os arquivos brutos ficam em brutos/.
for (pacote in c("data.table","jsonlite","pdftools")) {
  if (!requireNamespace(pacote,quietly=TRUE)) stop("Instale o pacote ",pacote)
}
library(data.table)
pasta <- "brutos"
destino <- "reconstruidos"
dir.create(destino,showWarnings=FALSE)
fontes <- jsonlite::fromJSON("fontes.json")
dir.create(pasta,showWarnings=FALSE)
if ("--baixar" %in% commandArgs(trailingOnly=TRUE)) {
  for (nome in names(fontes)) {
    path <- file.path(pasta,nome)
    if (file.exists(path)) next
    tmp <- tempfile(tmpdir=pasta)
    download.file(fontes[[nome]],tmp,mode="wb")
    stopifnot(file.rename(tmp,path))
  }
}
faltam <- names(fontes)[!file.exists(file.path(pasta,names(fontes)))]
if (length(faltam)) stop("Insumos ausentes em brutos/: ",paste(faltam,collapse=", "))
ler_zip <- function(arquivo,padrao,colunas) {
  zip <- file.path(pasta,arquivo)
  itens <- unzip(zip,list=TRUE)$Name
  membro <- grep(padrao,itens,value=TRUE,ignore.case=TRUE)
  stopifnot(length(membro)==1L,!grepl("(^/|[.][.]/)",membro))
  temp <- tempfile()
  dir.create(temp)
  on.exit(unlink(temp,recursive=TRUE))
  unzip(zip,files=membro,exdir=temp)
  # Importar apenas as colunas necessárias reduz memória. NIS permanece texto.
  ans <- fread(file.path(temp,membro),select=colunas,sep=";",encoding="Latin-1",
               colClasses="character",showProgress=interactive())
  setnames(ans,enc2utf8(names(ans)))
  ans
}
unir <- function(a,b,chave) {
  stopifnot(!anyDuplicated(b[, ..chave]))
  r <- merge(a,b,by=chave,all.x=TRUE,sort=FALSE)
  stopifnot(nrow(r)==nrow(a),!anyNA(r))
  r
}
cruz <- ler_zip("tsecross.zip","municipio_tse_ibge[.]csv$",
                c("SG_UF","CD_MUNICIPIO_TSE","CD_MUNICIPIO_IBGE"))
setnames(cruz,c("CD_MUNICIPIO_TSE","CD_MUNICIPIO_IBGE"),c("CD_MUNICIPIO","codigo_ibge"))
cruz <- unique(cruz[,.(SG_UF, CD_MUNICIPIO=as.integer(CD_MUNICIPIO),codigo_ibge=as.integer(codigo_ibge))])
votos <- function(ano) {
  v <- ler_zip(sprintf("tse%d.zip",ano),"_BR[.]csv$",
        c("SG_UF","CD_MUNICIPIO","NR_TURNO","NR_CANDIDATO","QT_VOTOS_NOMINAIS","DS_CARGO"))
  v <- v[toupper(DS_CARGO)=="PRESIDENTE" & SG_UF!="ZZ"]
  v[,CD_MUNICIPIO:=as.integer(CD_MUNICIPIO)]
  r <- v[,.(validos=sum(as.numeric(QT_VOTOS_NOMINAIS)),
            petista=sum(as.numeric(QT_VOTOS_NOMINAIS[NR_CANDIDATO=="13"]))),
         by=.(SG_UF,CD_MUNICIPIO,NR_TURNO)]
  r <- unir(r,cruz,c("SG_UF","CD_MUNICIPIO"))
  r[,pt:=petista/validos]
  if (ano==2018) fwrite(r[NR_TURNO=="1",.(codigo_ibge,haddad1=pt)],file.path(destino,"primeiro.csv"))
  r <- r[NR_TURNO=="2",.(codigo_ibge,validos,pt)]
  stopifnot(nrow(r)==5570,!anyDuplicated(r$codigo_ibge))
  setnames(r,c("validos","pt"),paste0(c("validos","pt"),ano))
  r
}
contar_nis <- function(nome,mes) {
  cols <- c("MÊS COMPETÊNCIA","CÓDIGO MUNICÍPIO SIAFI","NIS FAVORECIDO")
  x <- ler_zip(nome,"[.]csv$",cols)
  setnames(x,cols,c("mes_ref","siafi","nis"))
  unicos <- unique(x[mes_ref==mes & !is.na(nis) & nis!="" & !is.na(siafi) & siafi!="",
                      .(siafi=as.integer(siafi),nis)])
  unicos[,.(nis=.N),by=siafi]
}
normalizar <- function(x) gsub("[^A-Z0-9]","",iconv(toupper(x),to="ASCII//TRANSLIT"))
sidra <- function(nome) {
  t <- as.data.table(jsonlite::fromJSON(file.path(pasta,paste0(nome,".json"))))[-1]
  t[,.(codigo_ibge=as.integer(D1C),valor=as.numeric(fifelse(V=="-","0",V)),nome=D1N)]
}
pop <- sidra("pop")
uf <- sub(".* - ","",pop$nome)
tom <- sub(" - [[:upper:]]{2}$","",pop$nome)
chaves <- data.table(codigo_ibge=pop$codigo_ibge,uf,nome=normalizar(tom))
rec <- fread(file.path(pasta,"receita.csv"),sep=";",encoding="Latin-1",colClasses="character")
setnames(rec,c("tom_id","id","tom","ibge","uf"))
for (campo in c("tom","ibge")) {
  outros <- rec[id %in% pop$codigo_ibge & !is.na(get(campo)),
                .(codigo_ibge=as.integer(id),uf,nome=normalizar(get(campo)))]
  chaves <- unique(rbind(chaves,outros),by=c("uf","nome"))
}
linhas <- unlist(strsplit(pdftools::pdf_text(file.path(pasta,"folha.pdf")),"\n",fixed=TRUE))
padrao <- "^\\s*([A-Z]{2})\\s+(.+?)\\s+([0-9.]+)\\s+R\\$\\s+([0-9.,]+)\\s+R\\$\\s+([0-9.,]+)"
campos <- regmatches(linhas,regexec(padrao,linhas,perl=TRUE))
folha <- as.data.table(do.call(rbind,lapply(campos[lengths(campos)>0],function(m) m[2:6])))
setnames(folha,c("uf","municipio_folha","familias","total","media"))
numero <- function(s) as.numeric(chartr(",",".",gsub(".","",s,fixed=TRUE)))
folha[,familias:=numero(familias)]
# Dividir em centavos inteiros reproduz arredondamento monetário half-up.
centavos <- round(100*numero(folha$total))
divergem <- floor((2*centavos+folha$familias)/(2*folha$familias))!=round(100*numero(folha$media))
stopifnot(nrow(folha)==5570,sum(folha$familias)==20653849,sum(divergem)==2458)
folha[,nome:=normalizar(municipio_folha)]
folha <- merge(folha,chaves,by=c("uf","nome"),all.x=TRUE)
excecoes <- c("ITAPAGE"=2306306,"AUGUSTO SEVERO"=2401305,"PRESIDENTE JUSCELINO"=2410306,
 "SANTAREM"=2513653,"SAO DOMINGOS DE POMBAL"=2513968,"SERIDO"=2515401,"CAMPO DE SANTANA"=2516409,
 "DONA EUSEBIA"=3122900,"SAO THOME DAS LETRAS"=3165206,"TRAJANO DE MORAIS"=3305901,"EMBU"=3515004,
 "FLORINIA"=3516101,"MOJI MIRIM"=3530805,"SAO LUIS DO PARAITINGA"=3550001,"PICARRAS"=4212809,
 "PRESIDENTE CASTELO BRANCO"=4213906,"POXOREO"=5107008)
stopifnot(setequal(folha[is.na(codigo_ibge),municipio_folha],names(excecoes)))
folha[is.na(codigo_ibge),codigo_ibge:=unname(excecoes[municipio_folha])]
d <- folha[,.(codigo_ibge,uf,municipio_folha,familias)]
for (v in c("pop","edu","renda","dom","urb",paste0("age",0:13))) {
  x <- sidra(v)[,.(codigo_ibge,valor)]
  setnames(x,"valor",v)
  d <- unir(d,x,"codigo_ibge")
}
d[,urb:=100*urb/pop]
d[,jovens:=100*rowSums(.SD)/pop,.SDcols=paste0("age",0:5)]
d[,idosos:=100*rowSums(.SD)/pop,.SDcols=paste0("age",6:13)]
d[,(paste0("age",0:13)):=NULL]
mun <- jsonlite::fromJSON(file.path(pasta,"municipios.json"),simplifyVector=FALSE)
reg <- rbindlist(lapply(mun,function(x) {
  if (!is.null(x[["regiao-imediata"]])) data.table(codigo_ibge=as.integer(x$id),rgi=x[["regiao-imediata"]]$id)
}))
d <- unir(d,reg,"codigo_ibge")
for (a in c(2018,2022)) d <- unir(d,votos(a),"codigo_ibge")
siafi <- fread(file.path(pasta,"siafi.csv"),sep=";",header=FALSE,select=c(1,5),encoding="Latin-1")
setnames(siafi,c("siafi","codigo_ibge"))
siafi <- unique(siafi[,.(siafi=as.integer(siafi),codigo_ibge=as.integer(codigo_ibge))][codigo_ibge %in% pop$codigo_ibge])
atual <- unir(contar_nis("nis.zip","202209"),siafi,"siafi")
anterior <- unir(contar_nis("bf21.zip","202110"),siafi,"siafi")
stopifnot(sum(atual$nis)==20065780,sum(anterior$nis)==14654782,nrow(anterior)==5570)
fwrite(anterior[,.(codigo_ibge,nis21=nis)],file.path(destino,"favorecidos_out2021.csv"))
d <- unir(d,atual[,.(codigo_ibge,nis)],"codigo_ibge")
d[,folha:=1000*familias/pop]
d[,fav:=1000*nis/pop]
stopifnot(!anyDuplicated(d$codigo_ibge),nrow(d)==5570)
# Integrar os agregados antes de exportar a base de análise.
d <- unir(d, fread(file.path(destino,"primeiro.csv")), "codigo_ibge")
d <- unir(d, anterior[,.(codigo_ibge,nis21=nis)], "codigo_ibge")
sedes <- fread(file.path(pasta,"coords.csv"),select=c("codigo_ibge","latitude","longitude"))
d <- unir(d, sedes, "codigo_ibge")
fwrite(d[order(codigo_ibge)],file.path(destino,"base_municipal.csv"))
