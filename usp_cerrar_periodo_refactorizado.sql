USE [db_nomina]
GO
/****** Object:  StoredProcedure [dbo].[usp_cerrar_periodo]    Script Date: 1/6/2022 11:49:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<JOEL RAFAEL PAREDES BRIOSO>
-- Create date: <6/01/2022>
-- =============================================
ALTER PROCEDURE [dbo].[usp_cerrar_periodo]  

 @Nunquery						INT
,@Parametros					NVARCHAR(MAX)	= NULL
,@Xml							XML				= NULL
,@Codigo						INT				= NULL OUTPUT
,@Message						NVARCHAR(MAX)	= NULL OUTPUT
AS
BEGIN
BEGIN TRY
 DECLARE 
  @FecahTransActual                  DATETIME      = NULL,
  @Periodo			             	 INT		   = NULL,
  @PeriodoAct  		                 INT		   = NULL,
  @Fecha			             	 DATETIME	   = NULL,
  @AnioTrans                         INT		   = NULL,
  @MesTrans                          INT 		   = NULL,
  @PeriodoClosed	             	 INT		   = NULL,
  @IcodEmpresa                       INT           = NULL,
  @IfechaTrans                       DATETIME      = NULL

       -- ========================================== --
		-- ========================================== --
		--				SET PARAMETROS				  --
		-- ========================================== --
		-- ========================================== --

 IF(ISJSON(@Parametros) > 0)
 BEGIN
 SELECT 
 @IcodEmpresa      = DATOS.IcodEmpresa ,
 @IfechaTrans      =  DATOS.IfechaTrans
FROM OPENJSON(@Parametros, N'$')
WITH (
		    IcodEmpresa	    INT,
			IfechaTrans     DATETIME                 
			)  AS DATOS; 
 END
 IF(@Nunquery = 1)
 BEGIN
--@IfechaTrans: CONTIENE LA FECHA DE TRANSACCION SIQUIENTE
--@FecahTransActual: CONTIENE LA FECHA DE TRANSACION ACTUAL
                 IF EXISTS (
                 SELECT 1 
                 FROM tb_nomina 
                 WHERE n_estado = 'G' 
                 AND   n_cod_empresa = @IcodEmpresa 
                 AND   n_periodo = @Periodo)
                 BEGIN
             		SELECT 'ESTE PERIODO NO SE PUEDE CERRAR DEBIDO A QUE AUN NO SE A PROCESADO LA NOMINA.!!' AS MENSAJE
             		RETURN 1 
             	END 
--BUSCO EL PERIODO ACTUAL Y LA FECHA ANTE DE CERRARLO. 
                SELECT 
            	@periodo                     = pe_periodo, 
            	@FecahTransActual            = pe_fecha_trans 
            	FROM tb_periodos 
                WHERE pe_estado              = 'G' 
            	AND   pe_cod_empresa         = @IcodEmpresa
            
            	IF (@FecahTransActual > GETDATE())
                BEGIN
            		SELECT 'NO SE PUEDE CERRAR PERIODOS FUTUROS'        AS MENSAJE
            		RETURN 1 
            	END 
--CAMBIO EL ESTADO A LOS EMPLEADO LIQUIDADO
	           UPDATE tb_empleado SET e_estado = 'I'
	           WHERE e_codigo IN (SELECT lic_codEmpleado FROM tb_liquidacion WHERE lic_estado = 'G' )
	           AND e_estado = 'A'

--REBAJO LOS RENGLONES VARIABLES DE PERIODO ACTUAL	
           	 UPDATE tb_det_renglones_variables 
           	 SET   rv_det_saldo                          = 0
           	       ,rv_det_fecha_Act                     = GETDATE()
           	       ,rv_det_estado                        = 'C'
           	       ,rv_fecha_pago                        = GETDATE()
                WHERE  dbo.DateOnly(rv_det_fecha_trans)  = dbo.DateOnly(@FecahTransActual)
                AND rv_det_estado                        = 'G'  
           	    AND rv_det_cod_empresa                   = @IcodEmpresa


--//SALDO LOS RENGLONES PAGO
            UPDATE tb_renglones_variables 
     	    SET rv_estado = 'C'
            WHERE rv_codigo NOT IN (
     							     SELECT rv_det_codigo 
									 FROM tb_det_renglones_variables 
                                     WHERE rv_det_estado        = 'G'
     								  AND rv_det_cod_empresa    = @IcodEmpresa
                                       ) 
             AND  rv_estado       = 'G'
     		 AND rv_cod_empresa   = @IcodEmpresa
--END RENGLONES	

--ACTIVO LOS RENGLONES DESACTIVADO TEMP Y LO COLOCO PARA EL PROXIMO PERIODO.
        	 UPDATE tb_det_renglones_variables 
        		SET  rv_det_estado             = 'G'
        		   , rv_det_fecha_trans        = @IfechaTrans
        	  WHERE rv_det_estado              = 'T'
        	  AND rv_det_cod_empresa           = @IcodEmpresa
--REBAJO EL SALDO A FAVOR DEL ISR
     
        	 UPDATE isr 
        	    SET isr.sf_saldo        = isr.sf_saldo - isr.sf_isr
             FROM tb_saldo_favor_isr    AS isr
             INNER JOIN [tb_nomina] 
			 ON sf_cod_emp              =  [n_cod_empleado] AND [n_cod_items] IN (3)
             WHERE sf_estado            = 'G' 
               AND ISNULL(sf_saldo, 0)  > 0
                
             UPDATE tb_saldo_favor_isr 
        	     SET sf_saldo             = 0, 
				 sf_estado                = 'C'
             WHERE ISNULL(sf_saldo, 0)    <= 0 
        	 AND sf_estado                = 'G'
--------------------------
--SALDO LOS RENGLONES DE LOS EMPLEADO INACTIVO
	        UPDATE tb_det_renglones_variables 
	           SET rv_det_estado       = 'C'
	             , rv_det_saldo        = 0
	        WHERE rv_det_cod_emp IN (SELECT e_codigo FROM tb_empleado 
	        					     WHERE e_estado = 'I')
             AND  rv_det_estado        = 'G'
	         AND  rv_det_cod_empresa   = @IcodEmpresa	
	        
	        UPDATE tb_renglones_variables 
	           SET rv_estado           = 'C'
	        WHERE rv_cod_empleado IN (
	        							SELECT e_codigo 
	        						    FROM tb_empleado 
	        							WHERE e_estado = 'I'
	        						   )
	         AND  rv_estado            = 'G'
	         AND  rv_cod_empresa       = @IcodEmpresa
--END SALDO 


--GUARDO EL PERIODO ACTUAL PARA PODER EJECUTAR LA PARAMETRIZACION
	         SET @PeriodoAct             = @Periodo
             SET @Fecha                  = CONVERT(VARCHAR(10), GETDATE(), 101)



--CIERRO EL PRERIODO ACTUAL
            	UPDATE tb_periodos
            	  SET pe_fecha_cierre    = GETDATE()
            	    , pe_estado          = 'C'
            	WHERE pe_estado          = 'G' 
            	AND pe_cod_empresa       = @IcodEmpresa
            
            	SET @PeriodoClosed       = @Periodo
            
                IF @Periodo      = 1 
                BEGIN
            		SET @Periodo = 2
            	END
                ELSE 
                BEGIN
            		SET @Periodo = 1
            	END 


--CREO EL PERIODO 
	INSERT INTO  [dbo].[tb_periodos]
       (    
		    [pe_periodo]           ,[pe_fecha_trans]           ,[pe_fecha]
           ,[pe_fecha_Cierre]      ,[pe_estado]		           ,[pe_operador]
           ,[pe_terminal]		   ,[pe_cod_empresa]
	   )
     VALUES
        (
			 @periodo	          ,@IfechaTrans	           ,@Fecha
			,@Fecha		          ,'G'				       ,'SA'
			,'AUTOMATICO'		  ,@IcodEmpresa
		)

-- ACTUALIZAR SALDO PENDIENTE EMPLEADO
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
		            WHERE 1                           = 1 
		            AND [n_cod_items]                <> 10 
		            AND n_cod_empresa                 = @IcodEmpresa
		  	        GROUP BY n_cod_empleado
		  	        ORDER BY n_cod_empleado
		           
		            
		            UPDATE E 
		              SET E.e_saldo_pendiente          =  CASE WHEN INGRESO + (- e_saldo_pendiente) < 0 THEN  (INGRESO + (- e_saldo_pendiente)) * -1 ELSE 0 END 
		            FROM db_nomina..tb_empleado AS E
		            LEFT JOIN #SALDO ON n_cod_empleado = e_codigo
		            WHERE e_empresa                    = @IcodEmpresa

 --INSERTO LA NOMINA AL HISTORICO



                     INSERT INTO tb_nomina_hist 
                   	 SELECT * 
                   	 FROM tb_nomina 
                   	 WHERE n_cod_empresa         = @IcodEmpresa
                   
                   	 UPDATE tb_nomina_hist 
                   	 SET n_estado                = 'C' 
                   	 WHERE n_estado              <> 'C'
                   		      
                       --BORRO LA NOMINA ACTUAL 
                       DELETE FROM tb_nomina 
                   	 WHERE n_cod_empresa         = @IcodEmpresa
                       
                   	 UPDATE tb_det_renglones_variables 
                   	    SET rv_det_estado        = 'C'
                   	 WHERE rv_det_codigo IN (
                   								SELECT rv_codigo 
                   								FROM tb_renglones_variables
                   	  						    WHERE rv_estado = 'C' AND rv_codigo = rv_det_codigo
                   								AND rv_cod_empresa = @IcodEmpresa
                   								 )
                   	AND rv_det_estado        <> 'C'
                   	AND rv_det_cod_empresa   = @IcodEmpresa


					/*
	-- APLICAR PAGO EN PRESTACAR
	 DECLARE  @codEmpleado   INT
	        , @monto	     MONEY
			, @codPrestamo   INT
			 
	 DECLARE  C_APLICAR_PAGO CURSOR FOR 

	    SELECT DISTINCT
				n_cod_empleado			AS COD_EMPLEADO
			  , n_valor					AS MONTO
			  , n_refencia_prestamo     AS COD_PRESTAMO
		FROM db_nomina.dbo.tb_nomina
		WHERE n_cod_items = 69
		AND n_cod_empresa = @i_cod_empresa

     OPEN C_APLICAR_PAGO
	 FETCH NEXT FROM C_APLICAR_PAGO
	 INTO @codEmpleado , @monto, @codPrestamo
	 WHILE @@FETCH_STATUS = 0
	 BEGIN
		
		IF (@codPrestamo > 0)
		BEGIN
		  EXEC db_prestamos.PRESTAMO.usp_aplicar_pago 1, @codPrestamo, NULL, 1, NULL ,@fecha ,@monto, 'SA','SERVER',NULL,2,NULL,NULL, NULL
		END 

	  FETCH NEXT FROM C_APLICAR_PAGO
	  INTO @codEmpleado , @monto , @codPrestamo
	 END

	 CLOSE C_APLICAR_PAGO
	 DEALLOCATE C_APLICAR_PAGO
	 */



--CREO LA NOMINA DE DICHO PERIODO
	 EXEC usp_ejecutar_nomina  @IcodEmpresa

     SELECT 'PERIODO CERRADO SACTIFACTORIAMENTE.!!' AS MENSAJE

     SET @AnioTrans = YEAR(@FecahTransActual)            
     SET @MesTrans  = MONTH(@FecahTransActual)            
 
     --CREAR LA PARAMETRIZACION CONTABLE	
		EXEC [dbo].[usp_Parametrizacion_Contable_nomina]
				 @anio			= @AnioTrans
				,@mes			= @MesTrans
				,@periodo		= @PeriodoAct
				,@id_empresa	= @IcodEmpresa
                ,@ifecha_trans	= @FecahTransActual

		IF @PeriodoAct = 2 AND @IcodEmpresa != 5
		BEGIN
			EXEC usp_Parametrizacion_Contable_tss_nomina @AnioTrans, @MesTrans, @IcodEmpresa, @FecahTransActual
		END 

	--==============================================================
	--						ENVIO CORREO
	--==============================================================
	DECLARE @body				AS NVARCHAR(MAX)
			,@Text				AS NVARCHAR(MAX)
			,@terminal			AS NVARCHAR(50)
			,@usuario			AS NVARCHAR(50)
			,@Empresa			AS NVARCHAR(100)
			
	 SELECT  @terminal = HOST_NAME()
		    ,@fecha	   = GETDATE()

	 SELECT @Empresa = em_nombre 
	 FROM db_nomina.DBO.tb_empresa
	 WHERE em_codigo = @IcodEmpresa

-- MIGRAR HISTORICO DE COMISIONES CUANDO SE CIERRA EL PRIMER PERIODO
	 IF (@PeriodoClosed = 1)
	 BEGIN
		 DECLARE @year  INT
		 DECLARE @month INT

		 SET @year = CASE WHEN MONTH(@IfechaTrans) = 1 THEN YEAR(@IfechaTrans)-1 ELSE YEAR(@IfechaTrans) END
		 SET @month = CASE WHEN MONTH(@IfechaTrans) = 1 THEN 12 ELSE MONTH(@IfechaTrans)-1 END
		 EXEC db_facturacion.[dbo].[usp_cargar_comisiones_vendedores] 1, @year, @month,NULL,NULL,NULL,NULL,NULL,NULL, NULL
	 
	 END
-- NOTIFICACION DE ITEMS DE CATALOGO QUE LLEGARON A SU FIN --

	 EXEC db_nomina.[dbo].[usp_notificacion_renglones_variables] @IcodEmpresa, @IfechaTrans

--EXEC [db_nomina].[dbo].[usp_suspendidos_por_nomina] 1, NULL, @i_fechaTrans, @i_cod_empresa

          SELECT TOP 1  
			   @usuario             = ISNULL(is_usuario,'SA')
           FROM Administracion.dbo.tb_inicio_sesion
           WHERE UPPER(is_terminal) = @terminal
		   AND is_modulo            = 4
		   ORDER BY is_fecha DESC 
		   SET  @text =' <style>
							table, td, th
							{
								border:1px solid #732424;
								font-weight:bold;
								font-size:15px;
							}
							.header
							{
								background-color:#5FB404;
								color:white;
								font-size:20px;
								font-weight:bold;
								text-align:center;
							}
							</style>
							<table>
								<tr>
									<td colspan="2">
									 <center> <h2 style="color:#088A85; background-color:#CEF6CE;"> CIERRE DE PERIODO NOMINA </h2> </center>  
									</td>
								</tr>
								<tr>
									 <td class="header">EMPRESA</td>
									 <td>'+ @Empresa +'</td>
								</tr>
								<tr >
									<td class="header">PERIODO</td>
									<td>'+CAST(@PeriodoClosed AS nvarchar(10))+'</td>
								</tr>
								
								<tr >
									<td class="header">FECHA_TRANS</td>
									<td>'+CAST(@IfechaTrans AS nvarchar(50))+'</td>
								</tr>
								<tr >
									<td class="header">USUARIO</td>
									<td>'+upper(CAST(@usuario AS nvarchar(50)))+'</td>
								</tr>
								<tr>
									 <td class="header">TERMINAL</td>
									 <td>'+upper(CAST(@terminal AS nvarchar(50)))+'</td>
								</tr>
								<tr >
									<td class="header">FECHA</td>
									<td>'+CAST(@Fecha AS nvarchar(50))+'</td>
								</tr>
							</table> '
		
				SET @body = '<html> <body> ' +  @Text + '</html> </body>'
				EXEC msdb.dbo.sp_send_dbmail
							 @recipients			 = 'maribel.diaz@hunter.do;sabi.duarte@hunter.do'
							,@blind_copy_recipients  = 'ruben.miranda@hunter.do;watter.deaza@hunter.do'
							,@profile_name			 = 'notificaciones'  
							,@subject				 = 'CIERRE DE PERIODO NOMINA'
							,@body					 = @body
							,@body_format			 ='HTML'
	 
 END
 COMMIT TRAN
 END TRY 
		
		BEGIN CATCH
		
			-- caturar el error	--
					THROW;

				 DECLARE @Emensaje								AS NVARCHAR(MAX)
						,@fechas								AS DATETIME
						,@severity								AS INT
						,@line									AS INT 
						,@procedure								AS NVARCHAR(50)
						,@MSG                                   AS VARCHAR(MAX) 
	
				SELECT   @Emensaje								= ERROR_MESSAGE()
						,@severity								= ERROR_SEVERITY()
						,@line									= ERROR_LINE()
						,@fecha									= GETDATE()
						,@procedure								= ERROR_PROCEDURE()
						,@MSG                                   = ERROR_MESSAGE()
				SET @MESSAGE = 
				CONCAT(
				 @Emensaje	
				,@severity	
				,@line		
				,@fecha		
				,@procedure	
				,@MSG
				)

				
	
				IF(@@trancount > 0)

				SELECT @MESSAGE


					ROLLBACK TRANSACTION
					EXEC msdb.dbo.sp_send_dbmail
							 @recipients			 = 'watter.deaza@hunter.do; '
							,@blind_copy_recipients  = 'ruben.miranda@hunter.do;'--
							,@profile_name			 = 'notificaciones'  
							,@subject				 = 'ERROR: CIERRE DE PERIODO NOMINA'
							,@body					 = @MSG
							,@body_format			 ='HTML'
		
				
		END CATCH


		END
