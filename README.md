# Auxílio Brasil e voto em Lula em 2022

Reprodução em R do trabalho de Bruno Donadel Mainieri e Enrico Bertolini Prado. [Artigo em PDF](Artigo_Econometria_corrigido.pdf) · [Conversa com a IA](https://econo-chat.vercel.app/).

## Executar no RStudio

Extraia o projeto e abra `Trabalho_Econometria.Rproj`. No console, execute:

```r
source("reproduzir.R", encoding = "UTF-8")
```

Pelo terminal, use `Rscript reproduzir.R` na pasta do projeto. A análise foi testada com R 4.5.0. As rotinas que partem da base municipal usam apenas os pacotes que acompanham o R. O programa usa os dados municipais incluídos, recalcula as tabelas e os gráficos em `resultados/` e compara os números com as 14 tabelas de referência guardadas em `conferencia.rds`. Uma divergência interrompe a conferência e identifica a tabela e a coluna.

## Organização do projeto

O PDF contém o artigo. A base reúne folha, votos, covariáveis, contagens de 2021 e coordenadas das sedes por código IBGE. O arquivo `reproduzir.R` gera as tabelas e figuras. Ele chama `diagnosticos.R` para os testes de influência, dependência espacial e bootstrap. Os insumos da conferência numérica e os sorteios do bootstrap acompanham o projeto. As saídas são criadas em `resultados/` na execução.

As regressões de referência usam 5.570 municípios. Os modelos complementares usam 5.569 municípios em 26 UFs. A unidade da inclinação da folha é o ponto percentual de votos válidos em Lula por dez famílias adicionais na folha por mil habitantes. A tabela de referência inclui intervalos por UF, por região imediata e HC1. Nas comparações centrais, a rotina calcula CR1 por UF com referência t de 25 graus de liberdade.

Para reproduzir os 9.999 sorteios do artigo nas três ponderações, o bootstrap em R lê a matriz de sinais em `sinais_bootstrap.csv.gz`. Cada linha do arquivo contém um sorteio e cada coluna identifica uma UF. A matriz registra os sinais de Rademacher do gerador usado na versão anterior (semente 202211). A rotina recalcula estatísticas e intervalos e verifica uma réplica por reestimação direta. Nos testes de Moran, as 999 permutações são geradas pelo próprio R com semente 202211.

## Localizar as saídas

| Item do artigo | Arquivos em `resultados/` |
| --- | --- |
| Tabela 1 e Figura 1 | `descritivas.csv` e `figura_descritiva.pdf` |
| Tabela 2 | Linhas de peso igual em `progressao.csv` |
| Tabela 3 e Figura 2 | `referencia.csv`, `contraste_quartis.csv` e `ajustes.pdf` |
| Tabelas 4 e 5 e Figura 3 | `diagnosticos_referencia.csv`, `diagnosticos_centrais.csv`, `decis.csv`, `moran.csv` e `decis.pdf` |
| Tabela 6 e Figura 4 | `progressao.csv`, `wild.csv` e `intervalos_m3.pdf` |
| Contrastes e sensibilidades | `coeficientes_m5.csv`, `sensibilidades.csv`, `sem_uf.csv` e `vif.csv` |
| Tabela 7 | `expansao.csv` |

## Reconstrução opcional com microdados

A base municipal integrada acompanha o projeto. Para reconstruí-la, use `reconstruir_base.R`. Essa rotina adicional requer `data.table`, `jsonlite` e `pdftools`, acesso às fontes e memória para ler os arquivos administrativos. Os nomes e as URLs estão em `fontes.json`. Para baixar os arquivos que faltam e reconstruir, rode `Rscript reconstruir_base.R --baixar`. Se os insumos já estiverem em `brutos/`, use `Rscript reconstruir_base.R`. Os dados reconstruídos ficam em `reconstruidos/`. A rotina verifica a soma da folha, as 2.458 divergências de média monetária, as 17 exceções de nome e os totais dos NIS. Os registros individuais são usados apenas localmente.

A validação desta conversão partiu dos agregados municipais distribuídos e abrangeu as 14 tabelas de conferência. A reconstrução opcional teve a sintaxe verificada. A rotina com todos os arquivos brutos não foi executada nesta revisão. O ChatGPT fez a conversão dos scripts de reprodução para R e a comparação numérica com as saídas arquivadas.

## Registro de consulta às fontes

| Fonte consultada | Data e hora em São Paulo | HTTP |
| --- | --- | --- |
| <https://www.gov.br/casacivil/pt-br/assuntos/noticias/2022/setembro/auxilio-brasil-atinge-a-marca-de-20-65-milhoes-de-familias-contempladas> | 2026-11-22T23:52:58.387824-03:00 | 200 |
| <https://web.archive.org/web/20220809130456/https://www.gov.br/cidadania/pt-br/noticias-e-conteudos/desenvolvimento-social/noticias-desenvolvimento-social/auxilio-brasil-inclui-2-2-milhoes-de-familias-chega-a-um-total-de-20-2-milhoes-e-zera-fila> | 2026-11-22T23:52:56.755856-03:00 | 200 |
| <https://web.archive.org/web/20220922124034id_/https://www.gov.br/cidadania/pt-br/noticias-e-conteudos/desenvolvimento-social/noticias-desenvolvimento-social/auxilio-brasil-chega-a-marca-inedita-de-20-65-milhoes-de-familias-contempladas-em-setembro/pab-setembro.pdf> | 2026-11-22T23:52:56.932027-03:00 | 200 |
| <https://www.gov.br/mds/pt-br/privados/informe-auxilio-brasil-e-cadastro-unico/informe-gestores-862> | 2026-11-22T23:52:58.559775-03:00 | 200 |
| <https://www2.camara.leg.br/legin/fed/medpro/2023/medidaprovisoria-1164-2-marco-2023-793816-norma-pe.html> | 2026-11-22T23:52:56.475700-03:00 | 200 |
| <https://portaldatransparencia.gov.br/download-de-dados/bolsa-familia-pagamentos/202110> | 2026-11-22T23:53:00.611565-03:00 | 200 |
| <https://portaldatransparencia.gov.br/download-de-dados/auxilio-brasil/202209> | 2026-11-22T23:53:00.435577-03:00 | 200 |
| <https://sidra.ibge.gov.br> | 2026-11-22T23:52:59.535777-03:00 | 200 |
| <https://cowles.yale.edu/node/145881> | 2026-11-22T23:52:56.424028-03:00 | 200 |
| <https://www.tesourotransparente.gov.br/ckan/dataset/abb968cb-3710-4f85-89cf-875c91b9c7f6/resource/eebb3bc6-9eea-4496-8bcf-304f33155282/download/tabmun.csv> | 2026-11-22T23:52:56.427595-03:00 | 200 |
| <https://dadosabertos.tse.jus.br> | 2026-11-22T23:52:57.187590-03:00 | 200 |
