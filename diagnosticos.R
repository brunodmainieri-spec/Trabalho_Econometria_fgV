
# Influência, resíduos e dependência espacial ----
# Vizinhança em distância de grande círculo nas coordenadas das sedes.
n <- nrow(d)
rad <- pi/180
xyz <- with(d,cbind(cos(latitude*rad)*cos(longitude*rad),cos(latitude*rad)*sin(longitude*rad),sin(latitude*rad)))
vizinhos <- matrix(NA_integer_,n,8)
for (i in seq_len(n)) {
  corda2 <- (xyz[,1]-xyz[i,1])^2+(xyz[,2]-xyz[i,2])^2+(xyz[,3]-xyz[i,3])^2
  corda2[i] <- Inf
  vizinhos[i,] <- head(order(corda2,method="radix"),8)
}
origem <- rep(seq_len(n),each=8)
destino <- as.vector(t(vizinhos))
redes <- list("oito vizinhos"=rep(TRUE,length(origem)),
              "entre RGI"=d$rgi[origem]!=d$rgi[destino],"entre UF"=d$uf[origem]!=d$uf[destino])
mor <- diagnostico <- decis <- omitir <- vifs <- list()
for (j in 2:5) {
  a <- ajustar(formulas[[j]],d)
  m <- a$m
  e <- resid(m)
  b <- unname(coef(m)["F"])
  z <- e-mean(e)
  md <- as.vector(tapply(e,faixas(d$F,10),mean))
  decis[[j-1]] <- data.frame(M=j,decil=1:10,residuo_pp=md)
  loo <- sapply(levels(d$uf),function(u) coef(lm(formulas[[j]], data=d[d$uf!=u,]))[["F"]])
  omitir[[j-1]] <- data.frame(M=j,uf_omitida=names(loo),b=loo,diferenca=loo-b)
  manter <- cooks.distance(m)<=4/n
  indices <- list()
  for (rede in names(redes)) {
    i <- origem[redes[[rede]]]
    k <- destino[redes[[rede]]]
    escala <- n/length(i)/sum(z^2)
    indice <- function(v) escala*sum(v[i]*v[k])
    indices[[rede]] <- data.frame(M=j,rede,arestas=length(i),I=indice(z),p_perm=p_moran(z,indice))
  }
  mor <- c(mor,indices)
  diagnostico[[j-1]] <- data.frame(M=j,max_abs=max(abs(md)),cook_N=sum(!manter),
    sem_cook=coef(lm(formulas[[j]],data=d[manter,]))[["F"]],min_sem_uf=min(loo),max_sem_uf=max(loo),
    moran=indices[[1]]$I,moran_entre=indices[[2]]$I,p_perm=indices[[2]]$p_perm)
  if (j>=3) {
    termos <- intersect(c("F","H","ln_renda","edu","urb","jovens","idosos","ln_pop"),colnames(m$x))
    vars <- m$x[,termos,drop=FALSE]
    dentro <- apply(vars,2,function(v) v-ave(v,d$uf))
    completo <- cbind(vars,model.matrix(~uf,d)[,-1])
    for (tipo in c("dentro de UF","com dummies")) {
      X <- if (tipo=="dentro de UF") dentro else completo
      vifs[[length(vifs)+1]] <- data.frame(M=j,definicao=tipo,termo=termos,VIF=diag(solve(cor(X)))[termos])
    }
  }
}
salvar("decis",decis)
salvar("diagnosticos_centrais",diagnostico)
salvar("moran",mor)
salvar("sem_uf",omitir)
salvar("vif",vifs)

# Bootstrap por UF ----
# Cada coluna da matriz é uma réplica. Os sorteios arquivados são os do artigo.
sinais <- t(as.matrix(read.csv("sinais_bootstrap.csv.gz",check.names=FALSE)))
stopifnot(identical(rownames(sinais),levels(d$uf)),ncol(sinais)==9999)
wild <- function(j,peso) {
  a <- ajustar(formulas[[j]],d,pesos[[peso]])
  X <- a$m$x
  w <- weights(a$m)
  e <- resid(a$m)
  b <- coef(a$m)[["F"]]
  ep <- a$se[["F"]]
  coluna <- a$A[,"F"]
  h <- drop(X %*% coluna)
  agrupar <- function(v) rowsum(X*(w*v),d$uf)
  H <- agrupar(h)
  partes <- function(S) {
    delta <- a$A %*% t(S) %*% sinais
    list(beta=delta["F",],escore=drop(S %*% coluna)*sinais-H %*% delta)
  }
  livre <- partes(agrupar(e))
  restrito <- partes(H/coluna["F"])
  v0 <- a$correcao*colSums(livre$escore^2)
  v1 <- 2*a$correcao*colSums(livre$escore*restrito$escore)
  v2 <- a$correcao*colSums(restrito$escore^2)
  pvalor <- function(nula) {
    dif <- b-nula
    tstar <- (livre$beta+dif*restrito$beta)/sqrt(v0+dif*v1+dif^2*v2)
    (1+sum(abs(tstar)>=abs(dif/ep)))/(1+length(tstar))
  }
  # Valida o primeiro sorteio contra uma reestimação com H0: beta_F = 0.
  br <- coef(a$m)-coluna*b/coluna["F"]
  yr <- drop(X %*% br)
  sim <- d
  sim$Y <- yr+(d$Y-yr)*sinais[as.character(d$uf),1]
  replica <- ajustar(formulas[[j]],sim,pesos[[peso]])
  stopifnot(abs(coef(replica$m)[["F"]]-(livre$beta[1]+b*restrito$beta[1]))<1e-7,
            abs(replica$se[["F"]]-sqrt(v0[1]+b*v1[1]+b^2*v2[1]))<1e-7)
  limite <- function(lado) {
    dentro <- b
    fora <- b+lado*8*ep
    stopifnot(pvalor(fora)<.05)
    for (it in seq_len(29)) {
      centro <- (dentro+fora)/2
      if (pvalor(centro)>=.05) dentro <- centro else fora <- centro
    }
    dentro
  }
  data.frame(M=j,peso,lo=limite(-1),hi=limite(1),pzero=pvalor(0))
}
intervalos <- list()
for (j in 1:5) for (p in names(pesos)) intervalos[[length(intervalos)+1]] <- wild(j,p)
salvar("wild",intervalos)
