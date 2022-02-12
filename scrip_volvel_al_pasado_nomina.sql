
  CREATE TABLE [dbo].[tb_periodos] (
  pe_codigo        INT PRIMARY KEY IDENTITY,
  pe_cod_empresa   INT,
  pe_periodo       INT,
  pe_fecha_trans   DATETIME,
  pe_fecha         DATETIME,
  pe_fecha_cierre  DATETIME,
  pe_estado        VARCHAR(1),
  pe_operador      VARCHAR(50),
  pe_terminal      VARCHAR(50)
  )
  GO

  DELETE FROM [dbo].[tb_periodos]
  GO
  SELECT *   FROM [db_nomina].[dbo].[tb_periodos]
  WHERE pe_cod_empresa = 3 --AND pe_estado = 'G'
  ORDER BY pe_fecha DESC
 --DROP TABLE [dbo].[tb_periodos]
  UPDATE [db_nomina].[dbo].[tb_periodos]
  SET pe_estado ='G'
  WHERE pe_codigo IN(2010)

  UPDATE [db_nomina].[dbo].[tb_periodos]
  SET pe_estado ='C'
  WHERE pe_codigo IN(2024)

 

