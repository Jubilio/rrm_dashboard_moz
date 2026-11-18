footer_acknowledgements <- function() {
  partners <- c('nrc.svg'='Norwegian Refugee Council', 'impact.png'='IMPACT Initiatives',
    'save-the-children.svg'='Save the Children', 'pronanac.png'='PRONANAC Educacional',
    'acf.svg'='Action Contre la Faim', 'fdc.png'='Fundação para o Desenvolvimento da Comunidade',
    'solidarites.png'='Solidarités International')
  shiny::div(class='footer-acknowledgements',
    style='flex:0 0 100%;width:100%;max-width:100%;box-sizing:border-box;display:flex;flex-wrap:wrap;gap:20px;align-items:center;border-top:1px solid #C7C8CA;padding:12px 0;margin-top:8px;',
    shiny::div(class='footer-partners',style='flex:1 1 500px;min-width:0;',
      shiny::h2(class='footer-brand-heading',style='font:700 12px Arial,sans-serif;margin:0 0 10px;letter-spacing:0;color:#58585A;','Cooperating partners'),
      shiny::div(class='footer-partner-logos',style='display:flex;flex-wrap:wrap;align-items:center;gap:12px 18px;',lapply(names(partners),function(file)
        shiny::img(src=paste0('partners/',file),alt=partners[[file]],
          class='footer-partner-logo',width=115,height=42,
          style='display:block;width:115px;height:42px;max-width:100%;object-fit:contain;flex:0 0 115px;',loading='lazy')))),
    shiny::div(class='footer-donor',style='flex:0 0 110px;text-align:center;padding:0 10px;border:0;',
      shiny::h2(class='footer-brand-heading',style='font:700 12px Arial,sans-serif;margin:0 0 8px;letter-spacing:0;color:#58585A;','Funded by'),
      shiny::img(src='partners/eu-funded.png',alt='Funded by the European Union',
        class='footer-donor-logo',width=90,height=76,
        style='display:block;width:90px;height:76px;max-width:100%;object-fit:contain;margin:auto;',loading='lazy')))
}
