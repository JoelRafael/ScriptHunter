USE [db_nomina]
GO
/****** Object:  StoredProcedure [dbo].[usp_periodo]    Script Date: 2/11/2022 11:32:22 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Jonathan C. Bautista>
-- Create date: <Create Date,,10/11/2009>
-- =============================================
ALTER PROCEDURE [dbo].[usp_periodo]

@i_cod_empresa AS INT  

AS
BEGIN
	
		 if not exists (select * from tb_periodos where pe_cod_empresa = @i_cod_empresa)
		 begin
		 Declare @fecha varchar(12)
		 set @fecha =  convert(varchar, YEAR(getdate())) + '-' + convert(varchar, month(getdate())) + '-15'
			 
		  INSERT INTO [dbo].[tb_periodos]
					([pe_cod_empresa]					,[pe_periodo]					,[pe_fecha_trans]
					,[pe_fecha]     					,[pe_fecha_Cierre]   			,[pe_estado]
					,[pe_operador]   					,[pe_terminal])
			SELECT   @i_cod_empresa						,1								,@fecha 
					,getdate()							,getdate()						,'G'
					,'SA'								,'AUTOMATICO'
		 end


   IF ISNULL(@i_cod_empresa, 0) = 0
   BEGIN
	   SELECT TOP 1
			  pe_periodo     AS PERIODO, 
			  pe_fecha_trans AS FECHA_TRANS 
	   FROM tb_periodos WHERE pe_estado = 'G'
        ORDER BY pe_fecha_trans DESC
   END
   ELSE
   BEGIN
		SELECT 
			   pe_periodo								  AS PERIODO 
			  , pe_fecha_trans							  AS FECHA_TRANS 
              ,month(pe_fecha_trans)					  AS MES
              ,YEAR(pe_fecha_trans)						  AS YEARS
	   FROM tb_periodos WHERE pe_estado = 'G'
	     AND pe_cod_empresa = @i_cod_empresa
   END 
END



