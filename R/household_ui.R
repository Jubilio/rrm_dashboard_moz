household_ui <- function(id,h,allow_synthetic=TRUE) {
 ns<-shiny::NS(id)
 shiny::tagList(shiny::div(class='page-heading',shiny::div(shiny::span(class='eyebrow',if(allow_synthetic) 'HOUSEHOLD MATRIX · DRAFT 0.1' else 'REVIEWED OPERATIONAL AGGREGATES'),shiny::h2('Cross-sector need concurrence'))),
  if(allow_synthetic) shiny::div(class='method-strip','DRAFT MAPPINGS — not approved for targeting. Four sectors are counted once each; demographic characteristics and coping are not severity weights. The supplied workbook contains no assessed household dataset.'),
  shiny::div(class='filters',shiny::selectInput(ns('source'),'Aggregate source',if(allow_synthetic) c('Synthetic draft scenarios'='synthetic','Reviewed operational aggregates'='operational') else c('Reviewed operational aggregates'='operational')),
    shiny::selectInput(ns('population'),'Population',c('All','IDP','Host')),
    shiny::selectInput(ns('profile'),'Profile comparison',c('All households'='all_households','Head sex'='hhh_sex','Hosting others'='hosting_others','Repeated displacement'='repeat_displacement','Functional difficulty'='functional_difficulty_present')),
    shiny::downloadButton(ns('export'),'Export displayed aggregates')),
  shiny::uiOutput(ns('status')),
  shiny::div(class='panel',shiny::h3('Concurrence by profile · denominators and uncertainty'),DT::DTOutput(ns('summary')),
    shiny::p(class='muted','High need: level ≥3 in a sector. Concurrence: at least two high-need sectors. Bounds retain unresolved outcomes. IDP baseline and host samples remain separate; percentages describe assessed households only. Small or complementary cells are suppressed.')),
  if(allow_synthetic) shiny::div(class='panel',shiny::h3('Four-sector mapping rules · supplied draft'),DT::DTOutput(ns('rules'))),
  if(allow_synthetic) shiny::div(class='panel',shiny::h3('Pending methodological decisions'),DT::DTOutput(ns('decisions'))),
  if(allow_synthetic) shiny::div(class='panel',shiny::h3('Private analysis workflow'),
    shiny::p('Map the final survey export to data/templates/household_input.csv, then run scripts/run_household_analysis.R locally. Raw household data and record-level results are not loaded into this dashboard.'),
    shiny::p('Default analysis exports native indicators only. Draft sector calculations require an explicit scenario flag. Approved operational calculations require a recorded rule version and approval metadata. Only reviewed, approved aggregate output is accepted for operational display.')))
}
household_server <- function(id,h,allow_synthetic=TRUE) shiny::moduleServer(id,function(input,output,session) {
 table_data<-shiny::reactive({
  synthetic<-isTRUE(allow_synthetic)&&(is.null(input$source)||input$source=='synthetic')
  path<-if(synthetic) 'data/household/synthetic_aggregates.csv' else 'data/operational/household_aggregates.csv'
  if(!file.exists(path)) return(data.frame())
  a<-read.csv(path,stringsAsFactors=FALSE,na.strings='',check.names=FALSE)
  expected<-names(read.csv('data/household/synthetic_aggregates.csv',nrows=0,check.names=FALSE))
  if(!identical(names(a),expected)) return(data.frame())
  if(!synthetic) a<-a[!is.na(a$reviewed)&a$reviewed&!is.na(a$synthetic)&!a$synthetic&!is.na(a$rule_status)&a$rule_status=='approved',,drop=FALSE]
  a<-filter_equal(a,'population',input$population)
  a<-filter_equal(a,'profile',input$profile)
  a
 })
 output$status<-shiny::renderUI({
  a<-table_data();if(!nrow(a)) return(shiny::div(class='empty',shiny::h4('No reviewed, approved aggregate data available'),shiny::p('Generate aggregates from approved rules, review them, and save household_aggregates.csv in data/operational/.')))
  shiny::div(class='method-strip',if(isTRUE(allow_synthetic)&&(is.null(input$source)||input$source=='synthetic')) 'SYNTHETIC EXAMPLES ONLY — not linked to the historical alert registry; no operational households represented.' else 'Reviewed operational aggregates. No household records or eligibility lists are displayed.')
 })
 output$summary<-DT::renderDT(DT::datatable(table_data(),escape=TRUE,rownames=FALSE,options=list(scrollX=TRUE,pageLength=8)))
 output$rules<-DT::renderDT({a<-h$rules;names(a)<-c('Source row','Measure','Inputs','Level 1','Level 2','Level 3','Level 4','Missingness / aggregation','Basis');DT::datatable(a,escape=TRUE,rownames=FALSE,options=list(scrollX=TRUE,pageLength=5))})
 output$decisions<-DT::renderDT({a<-h$decisions;names(a)<-c('Source row','Decision','Draft proposal','Agreement needed','Reviewer','Status','Agreed rule / date');DT::datatable(a,escape=TRUE,rownames=FALSE,options=list(scrollX=TRUE,pageLength=5))})
 output$export<-shiny::downloadHandler(filename=function() paste0('rrm_household_aggregates_',if(allow_synthetic) input$source else 'operational','_',Sys.Date(),'.csv'),content=function(file) write.csv(table_data(),file,row.names=FALSE,na=''))
})
