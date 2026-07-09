## 1.2.0 (2026-07-09)
### Updated
-  Portato a ruby 4.0.1 (gestito con mise) e tutte le gemme all'ultima versione: watir 7.3 con selenium 4, simple_xlsx_reader 5.1, tzinfo 2, mongo 2.24, nokogiri 1.19  ( 2026-07-09 ) [ sphynx79]

### Changed
-  deterministic sostituita da functional-light-service 6.1 (Sequencer in_sequence, enum, Success/Failure); Settings interna al posto di settingslogic; rimossa activesupport in favore di dry-inflector  ( 2026-07-09 ) [ sphynx79]
-  scheduler.bat, download.bat e archivia.bat usano il ruby di mise tramite shim  ( 2026-07-09 ) [ sphynx79]

### Fixed
-  Token segreto Mapbox non piu' hardcodato nel codice: letto dalla variabile d'ambiente MAPBOX_SECRET_TOKEN (il vecchio token e' stato revocato)  ( 2026-07-09 ) [ sphynx79]
-  Kernel#open su URL (rimosso in Ruby 3) sostituito con URI.open; ERB.new con trim_mode keyword  ( 2026-07-09 ) [ sphynx79]



## 1.1.0 (2019-08-07)
### Changed
-  Aggiornato per farlo funzionare con il nuovo sito  ( 2019-08-07 ) [ sphynx]



## 1.0.7 (2019-05-24)
### Added
-  Aggiunto comando per esportare l'anagrafica da mapbox  ( 2019-05-24 ) [ sphynx79]



## 1.0.6 (2019-03-13)


## 1.0.5 (2018-11-05)
### Fixed
-  sistemato problema ora UTC, salvo le remit nel DB in formato UTC, ma nel server poi le visualizza in localtime  ( 2018-11-05 ) [ sphynx79]



## 1.0.4 (2018-10-10)


## 1.0.3 (2018-08-03)


## 1.0.2 (2018-04-16)
### Added
-  nei file exe controlla che ruby sia installato  ( 2018-04-16 ) [ sphynx79]



## 1.0.1 (2018-04-13)
### Changed
-  Aggiornato gitattribute  ( 2018-04-13 ) [ sphynx79]



## 1.0.0 (2018-04-13)







