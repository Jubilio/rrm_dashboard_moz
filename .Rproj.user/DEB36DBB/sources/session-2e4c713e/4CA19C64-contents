# Como iniciar o dashboard

Este é um novo projecto **R Shiny** com as cinco páginas do PDF: cobertura geográfica, alertas, Light RNA, vulnerabilidade e actividades. A interface está em inglês, seguindo o modelo enviado.

1. Extraia o ZIP.
2. Abra `rrm_dashboard.Rproj` no RStudio.
3. Na consola, execute:

```r
source("install_packages.R")
shiny::runApp(".", launch.browser = TRUE)
```

O dashboard abre com **dados fictícios**, identificados como demonstração. Os dados WASH do projecto anterior não foram utilizados como se fossem dados RRM.

Para usar dados reais, preencha os nove modelos CSV em `data/templates/`, guarde-os em `data/operational/` e altere `DATA_MODE` para `"operational"` em `config.R`. A linha de `metadata.csv` deve usar o mesmo modo. Consulte `README.md` e `DATA_DICTIONARY.md` para os campos, regras de contagem e relações entre tabelas. Reinicie a aplicação depois de actualizar os dados.

O mapa geográfico requer limites aprovados em GeoJSON e os pacotes opcionais indicados no README. As rotas são apresentadas de forma esquemática até existir informação geográfica verificada. A aplicação não está publicada nem ligada automaticamente ao Kobo.

A versão 2 integra os dois ficheiros metodológicos. A página Alerts tem um separador para o registo histórico. Vulnerability screening tem a análise agregada em rascunho. A interface mantém-se totalmente em inglês. As regras dos agregados familiares continuam provisórias, conforme o ficheiro enviado; consulte HOUSEHOLD_ANALYSIS.md para ligar dados reais.
