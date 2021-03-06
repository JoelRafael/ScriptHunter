USE [db_nomina]
GO
/****** Object:  StoredProcedure [dbo].[usp_ejecutar_Impuesto]    Script Date: 2/11/2022 12:55:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<JONATHAN C. BAUTISTA>
-- Create date: <10/11/2009>
-- CALCULO LOS IMPUESTOS EN BASE A LOS INGRESOS 
-- =============================================

--[dbo].[usp_ejecutar_Impuesto] 3

ALTER PROCEDURE [dbo].[usp_ejecutar_Impuesto] 

@i_cod_empresa INT

AS
BEGIN

  DECLARE @w_periodo	  INT,
		  @w_fecha_trans  DATETIME


    SELECT TOP 1
				@w_periodo     = [pe_periodo]
			   ,@w_fecha_trans = [pe_fecha_trans]
	FROM  [dbo].[tb_periodos]
	WHERE pe_estado = 'G' 
     AND pe_cod_empresa = @i_cod_empresa

	DELETE FROM [dbo].[tb_nomina] 
	WHERE  n_cod_empresa = @i_cod_empresa 
	AND [n_tipo] = 3

      --BUSCO LOS INGRESOS ANTERIORES
	 UPDATE tb_empleado 
		 SET e_ingresos_ant = 0 
	 WHERE e_empresa = @i_cod_empresa

	  SELECT COD_EMPLEADO, 
	         SUM(INGRESOS) AS INGRESOS 
	  INTO #temp_nomina 
	  FROM (

			/* AQUI AGREGO LOS CODIGO DE LOS ITEMS DE INGRESO QUE SE LE TOMARA EN CUENTA PARA LOS IMPUESTOS*/
			--2)	COMISIONES 
			--7)	VACACIONES 
			--0)	SALARIO 
            --15)	RETROACTIVO
			--52)	RESTO EL DESCUENTO POR DíAS NO LABORADOS
			--72)   AJUSTE
						
			SELECT n_cod_empleado  AS COD_EMPLEADO
			     , n_valor		   AS INGRESOS 
			FROM tb_nomina_hist
			WHERE n_tipo = 1 
			AND n_cod_items IN (2, 7, 0, 15, 72)
			AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			AND n_estado <> 'X' 
			AND n_cod_empresa = @i_cod_empresa
								 
			UNION ALL 
						             
			SELECT n_cod_empleado  AS COD_EMPLEADO
			     , n_valor		   AS INGRESOS  
			FROM tb_nomina
			WHERE n_tipo = 1 
			AND n_cod_items IN (2, 7, 0, 15, 72)   
			AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			AND n_estado <> 'X'
			AND n_cod_empresa = @i_cod_empresa 

			/*
			     --[BMEDRANO, 2-SEPT-2019] A PETICION DE DPTO CONTABILIDAD
			UNION ALL 
			
			SELECT n_cod_empleado AS COD_EMPLEADO, n_valor * -1 AS INGRESOS  
			FROM tb_nomina
			WHERE n_tipo = 2 
			AND n_cod_items IN (52,75)   
			AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			AND n_estado <> 'X'
			AND n_cod_empresa = @i_cod_empresa 
			AND N_cod_empresa IN (2,6)

			UNION ALL 

			SELECT n_cod_empleado AS COD_EMPLEADO, n_valor * -1 AS INGRESOS  
			FROM tb_nomina_hist
			WHERE n_tipo = 2 
			AND n_cod_items IN (52,75)   
			AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			AND n_estado <> 'X'
			AND n_cod_empresa = @i_cod_empresa 
			AND N_cod_empresa IN (2,6)
			*/
			
		 ) AS NOMINA
		  GROUP BY COD_EMPLEADO


         /*AQUI GUARDO LA SUMATORIA DE LOS INGRESO Y LO ACTUALIZO EN EL CAMPO E_INGRESOS_ANT, PARA UN MAYOR
          CONTROR DEL MISMO*/
		UPDATE EMP 
		    SET emp.e_ingresos_ant = INGRESOS 
		FROM tb_empleado AS EMP 
		LEFT JOIN #temp_nomina AS NOM ON e_codigo = cod_empleado
		WHERE e_empresa = @i_cod_empresa
	  
	     /*SI NO TUVO UN INGRESO ANTERIOR ENTONCE COLOCO EL SALARIO*/
		 UPDATE tb_empleado 
		    SET e_ingresos_ant =  e_salario
		 WHERE isnull(e_ingresos_ant, 0) = 0
		  AND e_empresa = @i_cod_empresa
			
	      DROP TABLE #temp_nomina

    ---------------------------------------------------------------------------------------------------------------------	

	--4. ASEGURADORA DE FONDE DE PENCION (AFP) 
	INSERT INTO [dbo].[tb_nomina]
       (
		 [n_cod_empleado]		    ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
		,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
		,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
		,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
		,[n_acreditacion]           ,[n_operador]                  ,[n_terminal]
	   )
			   
	SELECT 
   		   [CODIGO]		   		    ,[EMPLEADO]			   		  ,[COD_EMPRESA]	 		  ,[COD_OFICINA]
   		  ,[COD_DEPT]    		    ,[COD_PUESTO]		   		  ,PERIODO			   		  ,MES
   		  ,ANIO			   		    ,FECHA				   		  ,FECHA_TRANS		   		  ,[c_cod_items]
   		  ,[ca_descripcion]		    ,[ca_tipo]					  ,Valor		     		  ,ESTADO   			   
		  ,ID_ACREDITACION	   		,OPERADOR			  		  ,TERMINAL
    FROM ( 
			SELECT 
					 EM.[CODIGO]
					,EM.[EMPLEADO]
					,EM.[COD_EMPRESA]
					,EM.[COD_OFICINA]
					,EM.[COD_DEPT]
					,EM.[COD_PUESTO]
					,@w_periodo					 AS PERIODO
					,MONTH(@w_fecha_trans)		 AS MES
					,YEAR(@w_fecha_trans)		 AS ANIO
					,GETDATE()					 AS FECHA
					,@w_fecha_trans              AS FECHA_TRANS
					,[c_cod_items]
					,[ca_descripcion]
					,[ca_tipo]
					,
					/*
						SI SALARIO + COMISIONES + VACIONES ES MENOR O IGUAL QUE [im_sueldo_hasta] CALCULAR 
						LA SUMATORIA POR EL PORCENTAJE, LO CONTRARIO CALCULAR  [im_sueldo_hasta] POR EL PORCENTAJE. 
					*/
					CASE WHEN (INGRESO.VALOR) <= [im_sueldo_hasta] THEN 
						CASE WHEN [im_tipo_valor] = 0 THEN 
								INGRESO.VALOR * ([im_valor]/100) 
						ELSE
								[im_valor] 
						END 
					ELSE
						CASE WHEN [im_tipo_valor] = 0 THEN 
								[im_sueldo_hasta] * ([im_valor]/100) 
						ELSE
								[im_valor] 
						END 
					END											AS Valor
					/*
						FIN DEL CALCULO DE AFP
					*/	
					,'G'											AS ESTADO
					,EM.ID_ACREDITACION			
					,'SA'											AS OPERADOR
					,'AUTOMATICO'									AS TERMINAL
					, ISNULL(n_valor, 0)							AS VALOR_HIST
				FROM viw_empleado_nomina EM 
				INNER JOIN [dbo].[tb_conf_empleado] ON EM.[CODIGO] = [c_cod_empleado] AND [ESTADO] = 'A' AND [c_estado] = 1 AND c_tipo = 1 --NUNCA QUITAR
				INNER JOIN [dbo].[tb_catalogo] ON [ca_id] = [c_cod_items]
				INNER JOIN [dbo].[tb_conf_impuesto] ON [im_id_impuesto] = [c_cod_items] AND (im_periodo = @w_periodo OR im_periodo = 3)  --EL PERIDO 3 ES PARA QUE ME EJECUTE 15 Y 30
				LEFT JOIN tb_nomina_hist ON [n_cod_empleado] = EM.[CODIGO] AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans) 	AND n_estado <> 'X' AND [n_cod_items] = [ca_id]
				OUTER APPLY
				(
					 SELECT SUM(CASE WHEN n_tipo = 1 THEN n_valor ELSE n_valor * -1 END) AS VALOR
				     FROM tb_nomina
				     WHERE n_cod_empleado = EM.CODIGO
				     --AND n_cod_items IN (0,2,7,15,72) -- [BMEDRANO, 15-OCTUBRE-2019] A PETICION DE MARIBEL DIAZ, QUITAR ITEMS 46,52 
				     AND n_cod_items IN (0,2,7,15,72,75,CASE WHEN n_cod_empresa IN (2,6) THEN 52 ELSE 0 END) -- [BMEDRANO, 30-MAYO-2020] A PETICION DE MARIBEL DIAZ, VOLVER A PONER PERO SOLO A EMPRESA 2 Y 6

				) AS INGRESO
				WHERE COD_EMPRESA = @i_cod_empresa 
				AND [ca_id] = 4
	  ) AS DATOS 
	
---------------------------------------------------------------------------------------------------------------------	  

	--6. SEGURO FAMILIAR DE SALUD (SFS)
	INSERT INTO  [dbo].[tb_nomina]
			   ([n_cod_empleado]		   ,[n_nombre_empleado]           ,[n_cod_empresa]		   ,[n_cod_oficina]
			   ,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
			   ,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
			   ,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
			   ,n_acreditacion			   ,[n_operador]                  ,[n_terminal])
			   
	SELECT 
   			 [CODIGO]
   			,[EMPLEADO]
   			,[COD_EMPRESA]
   			,[COD_OFICINA]
   			,[COD_DEPT]
   			,[COD_PUESTO]
   			,PERIODO
   			,MES
   			,ANIO
   			,FECHA
   			,FECHA_TRANS
   			,[c_cod_items]
   			,[ca_descripcion]
   			,[ca_tipo]
   			,Valor --CASE WHEN PERIODO = 1 THEN Valor ELSE Valor - ISNULL(VALOR_HIST, 0) END VALOR
   			,ESTADO
   			,ID_ACREDITACION
   			,OPERADOR
   			,TERMINAL
   	    FROM ( 
				SELECT 
					   EM.[CODIGO]
					  ,EM.[EMPLEADO]
					  ,EM.[COD_EMPRESA]
					  ,EM.[COD_OFICINA]
					  ,EM.[COD_DEPT]
					  ,EM.[COD_PUESTO]
					  ,@w_periodo                  AS PERIODO
					  ,month(@w_fecha_trans)       AS MES
					  ,year(@w_fecha_trans)        AS ANIO      
					  ,GETDATE()				   AS FECHA
					  ,@w_fecha_trans			   AS FECHA_TRANS
					  ,[c_cod_items]
					  ,[ca_descripcion]
					  ,[ca_tipo]
					  ,
					   /*
						  SI SALARIO + COMISIONES + VACIONES ES MENOR O IGUAL QUE [im_sueldo_hasta] CALCULAR 
						  LA SUMATORIA POR EL PORCENTAJE LO CONTRARIO CALCULAR  [im_sueldo_hasta] POR EL PORCENTAJE. 
					   */
					   --CASE WHEN (INGRESO.VALOR + (CASE WHEN @w_periodo  = 2 THEN INGRESO_ANTERIOR.VALOR ELSE SALARIO / 2 END)) <= [im_sueldo_hasta] THEN 
					   CASE WHEN (INGRESO.VALOR + (CASE WHEN @w_periodo  = 2 THEN COALESCE(INGRESO_ANTERIOR.VALOR,0) ELSE SALARIO / 2 END)) <= [im_sueldo_hasta] THEN 
							CASE WHEN [im_tipo_valor] = 0 THEN 
									INGRESO.VALOR * ([im_valor]/100) 
							ELSE
									[im_valor] 
							END 
					   ELSE
						   CASE WHEN [im_tipo_valor] = 0 THEN 
									([im_sueldo_hasta]/2) * ([im_valor]/100) 
							ELSE
									[im_valor] 
							END 
					  END											AS Valor
					  /*
						 FIN DEL CALCULO DE SFS
					  */
					  ,'G'											AS ESTADO
					  ,EM.ID_ACREDITACION  
					  ,'SA'											AS OPERADOR
					 ,'AUTOMATICO'									AS TERMINAL
					 , ISNULL(n_valor, 0)							AS VALOR_HIST
				  FROM viw_empleado_nomina EM 
				  INNER JOIN [dbo].[tb_conf_empleado] ON EM.[CODIGO] = [c_cod_empleado] AND [ESTADO] = 'A' AND [c_estado] = 1 AND c_tipo = 1 --NUNCA QUITAR
				  INNER JOIN [dbo].[tb_catalogo] ON [ca_id] = [c_cod_items]
				  INNER JOIN [dbo].[tb_conf_impuesto] ON [im_id_impuesto] = [c_cod_items] AND (im_periodo = @w_periodo OR im_periodo = 3)  --EL PERIDO 3 ES PARA QUE ME EJECUTE 15 Y 30
				  LEFT JOIN tb_nomina_hist ON [n_cod_empleado] = EM.[CODIGO] AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans)  AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans) AND n_estado <> 'X' AND [n_cod_items] = [ca_id]
				  OUTER APPLY
				  (
					 SELECT SUM(CASE WHEN n_tipo = 1 THEN n_valor ELSE n_valor * -1 END) AS VALOR
				     FROM tb_nomina
				     WHERE n_cod_empleado = EM.CODIGO
				     --AND n_cod_items IN (0,2,7,15,72) -- [BMEDRANO, 15-OCTUBRE-2019] A PETICION DE MARIBEL DIAZ, QUITAR ITEMS 46,52
				     AND n_cod_items IN (0,2,7,15,72,75,CASE WHEN n_cod_empresa IN (2,6) THEN 52 ELSE 0 END) -- [BMEDRANO, 30-MAYO-2020] A PETICION DE MARIBEL DIAZ, VOLVER A PONER PERO SOLO A EMPRESA 2 Y 6
				   ) AS INGRESO
				   OUTER APPLY
				    (
						 SELECT SUM(CASE WHEN n_tipo = 1 THEN n_valor ELSE n_valor * -1 END) AS VALOR
						 FROM tb_nomina_hist
						 WHERE n_cod_empleado = EM.CODIGO
						 AND n_cod_items IN (0,2,7,15,52,46,72,75)
						 AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
						 AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
						 AND n_estado <> 'X'
				    ) AS INGRESO_ANTERIOR
				  WHERE COD_EMPRESA = @i_cod_empresa 
				  AND [ca_id] = 6
		 ) AS DATOS 
---------------------------------------------------------------------------------------------------------------------	  
	 /*
		 AQUI HAGO EL CALCULO DE ((SALARIO + COMISIONES + VACACIONES) - (AFP + SFS)) * 12
	 */ 
	 
	 /*
	    ANUALIZO EL INGRESO QUE TUVO EL EMPLEADO
	 */
	 
		SELECT [CODIGO]
		     , SUM([INGRESOS_ANT]) * 12 AS VALOR 
		INTO #temp_valor 
		FROM 
		 (
			SELECT [CODIGO]
			     , [INGRESOS_ANT] 
			FROM viw_empleado_nomina  
			 WHERE COD_EMPRESA = @i_cod_empresa 
            
            UNION ALL 

			--AGREGANDO LOS INCENTIVOS, LOS OTROS INGRESO, HORA EXTRA, BONO
			SELECT n_cod_empleado, n_valor 
			FROM tb_nomina_hist
			WHERE n_tipo = 1 
			AND n_cod_items IN (11, 13, 1, 25, 41,54,55)
			 AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			  AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			   AND n_cod_empresa = @i_cod_empresa 
				 AND n_estado <> 'X'
					 
			UNION ALL

			--AGREGANDO LOS INCENTIVOS, LOS OTROS INGRESO, HORA EXTRA, BONO
			SELECT n_cod_empleado
			     , n_valor 
			FROM tb_nomina
			WHERE n_tipo = 1 
			AND n_cod_items IN (11, 13, 1, 25, 41,54,55)
			 AND n_cod_empresa = @i_cod_empresa 
			   AND n_estado <> 'X' 

			UNION ALL 
			
			 --SUMO TODOS LOS IMPUESTOS EXECPTUANDO EL IMPUESTO SOBRE LA RENTA, PARA LUEGO RESTADO DEL INGRESO ANTERIOR Y NO COBRARLO DOS VECES
			SELECT [n_cod_empleado]
			     , SUM([n_valor]) * -1 
			FROM [tb_nomina_hist] 
			WHERE n_tipo = 3 
			AND [n_cod_items] <> 3	
			 AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) 
			  AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans)
			   AND n_cod_empresa = @i_cod_empresa 
				 AND n_estado <> 'X' 
				  GROUP BY [n_cod_empleado]
				
			UNION ALL
				  
            --SUMO TODOS LOS IMPUESTOS EXECPTUANDO EL IMPUESTO SOBRE LA RENTA, PARA LUEGO RESTADO DEL INGRESO ANTERIOR.
			SELECT [n_cod_empleado]
			     , SUM([n_valor]) * -1 
			FROM [tb_nomina] 
			WHERE n_tipo = 3 
			AND [n_cod_items] <> 3
			 AND n_cod_empresa = @i_cod_empresa AND n_periodo = @w_periodo
			  GROUP BY [n_cod_empleado]
		
			UNION ALL 
			
             --SACO EL SEGURO FAMILIAR DE SALUD DEPENDIENTE, LA CUAL DEBE SER RESTADO DEL INGRESO ANTERIOR.
		     SELECT  rf_cod_empleado, rf_valor * -1 
			 FROM [tb_renglones_fijos] 
			 WHERE rf_cod_items = 12
		      AND rf_tipo = 2 
			  AND rf_estado = 'G'
		) AS TOTAL
		 GROUP BY [CODIGO]

	--3. IMPUESTOS SOBRE LA RENTA (ISR)

	  INSERT INTO  [dbo].[tb_nomina]
	    (   
		     [n_cod_empleado]		    ,[n_nombre_empleado]           ,[n_cod_empresa]		    ,[n_cod_oficina]
			,[n_cod_dept]               ,[n_cod_puesto]                ,[n_periodo]             ,[n_mes]
			,[n_year]                   ,[n_fecha]                     ,[n_fecha_trans]         ,[n_cod_items]
			,[n_descripcion_items]      ,[n_tipo]                      ,[n_valor]               ,[n_estado]
			,[n_acreditacion]		    ,[n_operador]                  ,[n_terminal]
		)
			   
   	    SELECT 
   				 [CODIGO]
   				,[EMPLEADO]
   				,[COD_EMPRESA]
   				,[COD_OFICINA]
   				,[COD_DEPT]
   				,[COD_PUESTO]
   				,PERIODO
   				,MES
   				,ANIO
   				,FECHA
   				,FECHA_TRANS
   				,[c_cod_items]
   				,[ca_descripcion]
   				,[ca_tipo]
   				,CASE WHEN PERIODO = 1 THEN Valor ELSE Valor - ISNULL(VALOR_HIST, 0) END VALOR
   				,ESTADO
   				,ID_ACREDITACION
   				,OPERADOR
   				,TERMINAL
   	    FROM (  
				SELECT 
					   EM.[CODIGO]
					  ,EM.[EMPLEADO]
					  ,EM.[COD_EMPRESA]
					  ,EM.[COD_OFICINA]
					  ,EM.[COD_DEPT]
					  ,EM.[COD_PUESTO]
					  ,@w_periodo                   AS PERIODO
					  ,month(@w_fecha_trans)        AS MES
					  ,year(@w_fecha_trans)         AS ANIO   
					  ,GETDATE()				    AS FECHA	  
					  ,@w_fecha_trans				AS FECHA_TRANS
					  ,[c_cod_items] 
					  ,[ca_descripcion] 
					  ,[ca_tipo]

					  /*SI SUBE O BAJAN LOS IMPUESTOs SOBRE LA RENTA AQUI ES QUE DEBE 
						MODIFICAR LOS RANGO JCB <10/11/2009>*/

						/*
							MODIFICADO POR WELL 01/15/2016
							En vez del Hard Code
							select im_sueldo_hasta, * from [tb_conf_impuesto]
							where im_codigo in (1,4,5,6)

							select [dbo].[Valor_ISR](1)  
							select [dbo].[Valor_ISR](4),   [dbo].[Valor_ISR](4) - [dbo].[Valor_ISR](1)
							select [dbo].[Valor_ISR](5)  					

						*/
						,[dbo].[calculo_ISR] (temp.valor) AS Valor
					  -- (CASE WHEN (temp.valor) <= [dbo].[Valor_ISR](1)  THEN 
							--  0
							--WHEN (temp.valor) <= [dbo].[Valor_ISR](4) THEN 
					        
							--	CASE WHEN [im_tipo_valor] = 0 THEN 
							--			(((temp.valor  - ([im_sueldo_desde] - 0.01)) * ([im_valor]/100)) + 0) / 12
							--	ELSE
							--			[im_valor] 
							--	END 
								
							--WHEN (temp.valor) <= [dbo].[Valor_ISR](5) THEN  
							
							--	CASE WHEN [im_tipo_valor] = 0 THEN 
							--			(((temp.valor  - ([im_sueldo_desde] - 0.01)) * ([im_valor]/100)) + 29994) / 12
							--	ELSE
							--			[im_valor] 
							--	END  
								
							--WHEN (temp.valor) > [dbo].[Valor_ISR](5) THEN  
							
							--	CASE WHEN [im_tipo_valor] = 0 THEN 
			    --						(((temp.valor  - ([im_sueldo_desde] - 0.01)) * ([im_valor]/100)) + 76652) / 12
							--	ELSE
							--			[im_valor] 
							--	END 
						 --  END)					                        AS Valor
					  /*
						 FIN DEL CALCULO DE ISR
					  */
					  ,'G'                                             AS ESTADO
					  ,EM.ID_ACREDITACION  
					  ,'SA'											   AS OPERADOR
					 ,'AUTOMATICO'									   AS TERMINAL
					 , ISNULL(n_valor, 0)							   AS VALOR_HIST
				  FROM viw_empleado_nomina EM 
				  INNER JOIN [dbo].[tb_conf_empleado] ON EM.[CODIGO] = [c_cod_empleado]	AND [ESTADO] = 'A' AND [c_estado] = 1 AND c_tipo = 1 --NUNCA QUITAR
				  INNER JOIN [dbo].[tb_catalogo] ON [ca_id] = [c_cod_items]
				  INNER JOIN [#temp_valor] temp ON temp.codigo = [c_cod_empleado]
				  INNER JOIN [dbo].[tb_conf_impuesto] ON [im_id_impuesto] = [c_cod_items] AND temp.valor BETWEEN [im_sueldo_desde] AND [im_sueldo_hasta] AND (im_periodo = @w_periodo OR im_periodo = 3) 
				  LEFT JOIN tb_nomina_hist ON [n_cod_empleado] = EM.[CODIGO] AND MONTH([n_fecha_trans]) = MONTH(@w_fecha_trans) AND YEAR([n_fecha_trans]) = YEAR(@w_fecha_trans) AND n_estado <> 'X' AND [n_cod_items] = [ca_id] AND [n_periodo] = 1
				  WHERE COD_EMPRESA = @i_cod_empresa AND [ca_id] = 3
	     ) DATOS 
	  
      DROP TABLE #temp_valor 
	  
    --INSERTO LOS SALDO A FAVOR DEL ISR
    EXEC usp_saldo_favor_isr @i_cod_empresa

    --SALDO PENDIENTE DE PAGAR
    EXEC usp_saldo_pendiente @i_cod_empresa

	--EXEC [db_nomina].[dbo].[usp_ejecutar_nomina_suspendido]

END

