USE [db_nomina]
GO
/****** Object:  StoredProcedure [dbo].[usp_saldo_pendiente]    Script Date: 2/11/2022 12:59:51 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<JONATHAN C. BAUTISTA>
-- Create date: <05/12/2009>
-- =============================================

ALTER PROCEDURE [dbo].[usp_saldo_pendiente] 

@i_cod_empresa INT

AS
BEGIN

   --        	DECLARE @cod_emp	AS INT
			--DECLARE CursorSaldoPendiente CURSOR FOR

			--SELECT DISTINCT n_cod_empleado FROM  [dbo].[tb_nomina]
			--  	WHERE  n_cod_empresa = @i_cod_empresa 

			--OPEN CursorSaldoPendiente
			--FETCH next FROM CursorSaldoPendiente
			--INTO @cod_emp
			--WHILE @@FETCH_STATUS = 0

			--BEGIN
			--	DECLARE @i_saldo_pendiente AS MONEY
			--		  , @i_valor_actual    AS MONEY 
			--		  , @i_valor		   AS MONEY 
				
			--	SET @i_valor = 0
				
			--  --BUSCO EL SALDO PENDIENTE
   --           SELECT @i_saldo_pendiente = ISNULL(e_saldo_pendiente, 0) FROM [tb_empleado] 
			--		WHERE [e_codigo] = @cod_emp 

			--  SELECT 
			--		 @i_valor_actual	 =  CAST(SUM(
			--										CASE WHEN n_tipo = 1 THEN
			--											   n_valor 
			--											 ELSE n_valor * -1	
			--										 END) AS NUMERIC(10, 2)) 
			--  FROM  [dbo].[tb_nomina] WHERE n_cod_empleado =  @cod_emp
			--    AND [n_cod_items] <> 10 AND n_cod_empresa = @i_cod_empresa 
			  
              
   --           IF ISNULL(@i_valor_actual, 0) < 0 
   --           BEGIN
			--	  SET @i_valor = @i_valor_actual    
			--  END
			--  ELSE IF ISNULL(@i_saldo_pendiente, 0) < 0
			--  BEGIN
			--	 SET @i_valor = @i_saldo_pendiente * -1
			--  END 
			--  ELSE
			--  BEGIN
			--	  SET @i_valor = @i_saldo_pendiente
			--  END 

			--  IF (@i_valor_actual > 0 AND @i_saldo_pendiente < 0)
			--  BEGIN 
			--	  SET @i_valor = 0
			--  END 


   --           UPDATE [dbo].[tb_empleado] SET e_saldo_pendiente = @i_valor
			--	 WHERE [e_codigo] = @cod_emp AND e_empresa = @i_cod_empresa 


			--  FETCH next FROM CursorSaldoPendiente
			--  INTO @cod_emp
			--END

			--CLOSE CursorSaldoPendiente
			--DEALLOCATE CursorSaldoPendiente			

        
	      IF OBJECT_ID('tempdb..#SALDO') IS NOT NULL
		  BEGIN 
		    DROP TABLE #SALDO
		  END

		  SELECT CAST(SUM(CASE WHEN n_tipo = 1 THEN
									    n_valor 
									ELSE n_valor * -1	
									 END) AS NUMERIC(10, 2))  AS INGRESO,
									  n_cod_empleado
		  INTO #SALDO
	      FROM  [dbo].[tb_nomina] 
		  WHERE 1 = 1 
		   AND [n_cod_items] <> 10 
		    AND n_cod_empresa = 3
			 GROUP BY n_cod_empleado
			  ORDER BY n_cod_empleado

		----------------------------------------------------------------------------------------------------------------------	
		DECLARE @w_periodo INT, @w_fecha_trans DATETIME
		
		SELECT TOP 1
		 	 @w_periodo     = [pe_periodo]
		    ,@w_fecha_trans = [pe_fecha_trans]
	    FROM [dbo].[tb_periodos] WHERE pe_estado = 'G' 
		  AND pe_cod_empresa = @i_cod_empresa

		--ELIMINO EL ITEMS 10 DE SALDO PENDIENTE DE LA NOMINA, PARA INSERTARLO OTRA VEZ  
		DELETE FROM  [dbo].[tb_nomina] WHERE [n_cod_items] = 10 AND [n_cod_empresa] = @i_cod_empresa

		--INSERTO LOS SALDO PENDIENTE-----------------------------------------------------------------------------------------
		INSERT INTO [dbo].[tb_nomina]
				   ([n_cod_empleado]		   ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
				   ,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
				   ,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
				   ,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
				   ,n_acreditacion             ,[n_operador]                  ,[n_terminal])
		 SELECT 
			   EM.[CODIGO]					  ,EM.[EMPLEADO]				  ,EM.[COD_EMPRESA] 	  ,EM.[COD_OFICINA]
			  ,EM.[COD_DEPT]				  ,EM.[COD_PUESTO]          	  ,@w_periodo			  ,MONTH(@w_fecha_trans)
			  ,YEAR(@w_fecha_trans)        	  ,GETDATE()					  ,@w_fecha_trans   	  ,'10' 
			  ,'SALDO PENDIENTE'			  ,2							  ,CASE WHEN INGRESO < 0 THEN INGRESO + (-SALDO_PENDIENTE) ELSE SALDO_PENDIENTE END     	  ,'G'
			  ,EM.ID_ACREDITACION			  ,'SA'							  ,'AUTOMATICO'
		 FROM [dbo].viw_empleado_nomina EM 
		 LEFT JOIN #SALDO ON n_cod_empleado = CODIGO
		   WHERE COD_EMPRESA = @i_cod_empresa AND ISNULL(SALDO_PENDIENTE, 0) <> 0
END
