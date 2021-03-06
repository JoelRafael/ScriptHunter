USE [db_nomina]
GO
/****** Object:  StoredProcedure [dbo].[usp_ejecutar_nomina]    Script Date: 2/11/2022 12:54:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<JONATHAN C. BAUTISTA>
-- Create date: <10/11/2009>
-- Description:	<CREO LA NOMINA>
-- =============================================

ALTER PROCEDURE [dbo].[usp_ejecutar_nomina]  
 
@i_cod_empresa INT

AS
BEGIN

DECLARE @w_periodo		AS INT,
		@dias_mes		AS INT,
		@w_fecha_trans  AS DATETIME,
		@usuario		AS NVARCHAR(50),
		@terminal		AS NVARCHAR(50)



	  SELECT TOP 1
		   @w_periodo     = [pe_periodo]
		  ,@w_fecha_trans = [pe_fecha_trans]
		  ,@terminal	  = HOST_NAME()
	  FROM  [dbo].[tb_periodos]
	  WHERE pe_estado = 'G' 
	  AND pe_cod_empresa = @i_cod_empresa

	  SELECT TOP 1  
			@usuario = ISNULL(is_usuario,'SA')
      FROM Administracion.dbo.tb_inicio_sesion
      WHERE UPPER(is_terminal) = @terminal
	  AND is_modulo = 4
	  ORDER BY is_fecha DESC 

	  DELETE FROM  [dbo].[tb_nomina] 
	  WHERE  n_cod_empresa = @i_cod_empresa
	  AND [n_tipo] NOT IN (3)

      --REGLONES VARIABLES---------------------------------------------------------------------------------------------------
	  INSERT INTO  [dbo].[tb_nomina]
			   ([n_cod_empleado]		   ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
			   ,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
			   ,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
			   ,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
			   ,n_acreditacion			   ,[n_operador]                  ,[n_terminal]			   ,n_refencia_prestamo )

	   SELECT 
		   EM.[CODIGO]					   ,EM.[EMPLEADO]				  ,EM.[COD_EMPRESA]  	   ,EM.[COD_OFICINA]
		  ,EM.[COD_DEPT]				   ,EM.[COD_PUESTO]				  ,[rv_det_periodo]		   ,MONTH(@w_fecha_trans)
		  ,YEAR(@w_fecha_trans)            ,GETDATE()					  ,[rv_det_fecha_trans]    ,[rv_det_cod_items]
		  ,[ca_descripcion]				   ,[ca_tipo]					  ,[rv_det_saldo] 		   ,'G'
		  ,EM.ID_ACREDITACION              ,@usuario					  ,host_name()			   ,rv_det_cod_referencia_prestamo--+ CONVERT(VARCHAR, rv_det_num)
	   FROM viw_empleado_nomina EM 
	   INNER JOIN [dbo].[tb_det_renglones_variables] on [rv_det_cod_emp] = EM.[CODIGO]
	   INNER JOIN [dbo].[tb_catalogo] ON [ca_id] = [rv_det_cod_items]
	   WHERE COD_EMPRESA = @i_cod_empresa 
		AND rv_det_id IN 
						(
						   SELECT  rv_det_id 
						    FROM [tb_det_renglones_variables] 
							 WHERE [rv_det_cod_items] = [ca_id]
							  AND rv_det_estado = 'G' and [rv_det_fecha_trans] = @w_fecha_trans 
							   AND rv_det_cod_emp = EM.[CODIGO]
	 					 )

      --REGLONES FIJOS-------------------------------------------------------------------------------------------------------
	  INSERT INTO [dbo].[tb_nomina]
	   (
		    [n_cod_empleado]		   ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
		   ,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
		   ,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
		   ,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
		   ,n_acreditacion			   ,[n_operador]	              ,[n_terminal]
	   )
	   SELECT 
		    EM.[CODIGO]					  ,EM.[EMPLEADO]				  ,EM.[COD_EMPRESA]	 	  ,EM.[COD_OFICINA]
		   ,EM.[COD_DEPT]				  ,EM.[COD_PUESTO]				  ,@w_periodo			  ,MONTH(@w_fecha_trans)
		   ,YEAR(@w_fecha_trans)			  ,GETDATE()					  ,@w_fecha_trans		  ,[rf_cod_items]
		   ,[ca_descripcion]				  ,[ca_tipo]					  ,[rf_valor]			  ,'G'
		   ,EM.ID_ACREDITACION  			  ,@usuario						  ,@terminal
	   FROM viw_empleado_nomina EM 
	   INNER JOIN [dbo].[tb_renglones_fijos] on [rf_cod_empleado] = EM.[CODIGO] AND (rf_periodo = @w_periodo OR rf_periodo = 3)  AND rf_estado <> 'X' AND [rf_fecha_trans] <= @w_fecha_trans
	   INNER JOIN [dbo].[tb_catalogo] on [ca_id] = [rf_cod_items]
       WHERE COD_EMPRESA = @i_cod_empresa --AND ISNULL([rf_valor], 0) <> 0

      --REGLONES SALARIO-----------------------------------------------------------------------------------------------------
	   INSERT INTO [dbo].[tb_nomina]
	    (
		    [n_cod_empleado]		   ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
		   ,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
		   ,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
		   ,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
		   ,[n_operador]               ,[n_terminal]				  ,[n_acreditacion]
		)
	  SELECT 
		   EM.[CODIGO]				   ,EM.[EMPLEADO]				  ,EM.[COD_EMPRESA]		    ,EM.[COD_OFICINA]
		  ,EM.[COD_DEPT]			   ,EM.[COD_PUESTO]		  	      ,@w_periodo			    ,MONTH(@w_fecha_trans)
		  ,YEAR(@w_fecha_trans)        ,GETDATE()					  ,@w_fecha_trans	 	    ,'0'  
		  ,'SUELDO'					   ,1	 
		  ,  CASE WHEN ISNULL(FECHA_SALIDA, '') <> '' THEN 
					   CAST((salario / CASE WHEN COD_PUESTO IN (99 ,47, 108,112,113,115,116,117) THEN 26 ELSE 23.83 END) * dbo.DifDias(FECHA_SALIDA) AS NUMERIC(20, 2))
				ELSE 
					   CASE WHEN DATEDIFF(d, fecha_ing, @w_fecha_trans) < 14 THEN 
							CAST((salario / CASE WHEN COD_PUESTO IN (99 ,47, 108,112,113,115,116,117) THEN 26 ELSE 23.83 END) * (dbo.DifDias1(fecha_ing, @w_fecha_trans)) AS NUMERIC(20, 2)) 
					   ELSE			
							CAST((salario / 2) AS NUMERIC(20, 2))
					   END  
				END	AS VALOR
		  ,'G'									  
		  ,@usuario				  
		  ,@terminal
		  ,EM.ID_ACREDITACION  
	FROM viw_empleado_nomina EM 
	WHERE COD_EMPRESA = @i_cod_empresa 
	   
	-- ==================================== --
	-- ===== PROGRAMA FASE (COVID-19) ===== --
	-- ==================================== --

	DELETE EFP
	   FROM db_nomina.[dbo].[tb_empleados_fase_periodo] EFP
	   WHERE EFP.efp_estado = 1
	   AND EFP.efp_cod_empresa = @i_cod_empresa
	   AND EFP.efp_fecha_trans = @w_fecha_trans

	INSERT INTO db_nomina.[dbo].[tb_empleados_fase_periodo]
    (
		[efp_fecha_ing]           ,[efp_usuario_ing]           ,[efp_terminal_ing]
       ,[efp_estado]              ,[efp_cod_empleado]          ,[efp_cod_empresa]
       ,[efp_fecha_trans]		  ,[efp_valor]
	)
	SELECT 
		GETDATE()				  ,@usuario					   ,@terminal
	   ,1						  ,N.n_cod_empleado			   ,@i_cod_empresa
	   ,@w_fecha_trans			  ,EF.ef_valor  
	   FROM db_nomina..tb_nomina N
	   INNER JOIN db_nomina..tb_empleados_fase EF ON EF.ef_cod_empleado = N.n_cod_empleado AND EF.ef_estado = 1
	   WHERE N.n_cod_items = '0'
	   AND N.n_cod_empresa = @i_cod_empresa

	UPDATE N
	   SET N.n_valor = (N.n_valor - EF.ef_valor)
	   FROM db_nomina..tb_nomina N
	   INNER JOIN db_nomina..tb_empleados_fase EF ON EF.ef_cod_empleado = N.n_cod_empleado AND EF.ef_estado = 1
	   WHERE N.n_cod_items = '0'
	   AND N.n_cod_empresa = @i_cod_empresa

	EXEC usp_ejecutar_Impuesto @i_cod_empresa 
 
END
