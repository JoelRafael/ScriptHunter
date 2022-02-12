
DELETE FROM db_nomina..tb_nomina_hist WHERE n_codigo IN (

SELECT * FROM db_nomina..tb_nomina_hist H 
--INNER JOIN db_nomina..tb_catalogo C ON C.ca_id =H.n_cod_items 
--WHERE ca_id = 4
--
WHERE H.n_cod_empresa = 3
AND CAST(H.n_fecha AS DATE) >='2022-02-01'
AND n_tipo =3

)


