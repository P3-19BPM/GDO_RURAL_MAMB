SELECT OCO.numero_ocorrencia,                                -- Número da ocorrência *****Manutenção de Rede de Proteção Preventiva (MRPP)***
OCO.natureza_codigo,                                         -- Código da natureza da ocorrência
OCO.natureza_descricao,                                      -- Descrição da natureza da ocorrência
CASE 
    WHEN OCO.codigo_municipio IN (310090 , 310100 , 310170 , 310270 , 310340 , 310470 , 310520 , 310660 , 311080 , 311300 , 311370 , 311545 , 311700 , 311950 , 312015 , 312235 , 312245 , 312560 , 312675 , 312680 , 312705 , 313230 , 313270 , 313330 , 313400 , 313470 , 313507 , 313580 , 313600 , 313650 , 313700 , 313890 , 313920 , 314055 , 314140 , 314315 , 314430 , 314490 , 314530 , 314535 , 314620 , 314630 , 314675 , 314850 , 314870 , 315000 , 315217 , 315240 , 315510 , 315660 , 315710 , 315765 , 315810 , 316030 , 316330 , 316555 , 316670 , 316860 , 317030 , 317160) THEN '15 RPM'	
    ELSE 'OUTROS'	
END AS RPM_2025_AREA,
CASE 
    WHEN OCO.codigo_municipio IN (310470,311080,311300,311545,312675,312680,313230,313270,313507,313700,313920,314490,314530,314535,314620,314850,315000,315240,316330,316555,316860) THEN '19 BPM'
    WHEN OCO.codigo_municipio in (310090,310660,311370,312015,312705,313890,314430,315765,316670,317030) THEN '24 CIA PM IND'
    WHEN OCO.codigo_municipio in (310170,310520,312245,312560,313470,313580,313600,313650,314055,314315,314675,315510,315660,315710,315810,316030,310100,310270,312235,314870) THEN '44 BPM'
    WHEN OCO.codigo_municipio in (310340,311950,313400,314630,317160,311700,313330,314140,315217) THEN '70 BPM'
    ELSE 'OUTROS'
END AS UEOP_2025_AREA,
LO.codigo_unidade_area,										-- Código da unidade militar da área
LO.unidade_area_militar_nome,                                -- Nome da unidade militar da área
OCO.unidade_responsavel_registro_codigo,                      -- Código da unidade que registrou a ocorrência
OCO.unidade_responsavel_registro_nome,                        -- Nome da unidade que registrou a ocorrência
SPLIT_PART(OCO.unidade_responsavel_registro_nome,'/',-1) RPM_REGISTRO, 
SPLIT_PART(OCO.unidade_responsavel_registro_nome,'/',-2) UEOP_REGISTRO, 					 
	CASE 																			-- se o território é Urbano ou Rural segundo o IBGE
    	WHEN OCO.pais_codigo <> 1 AND OCO.ocorrencia_uf IS NULL THEN 'Outro_Pais'  	-- trata erro - ocorrencia de fora do Brasil
		WHEN OCO.ocorrencia_uf <> 'MG' THEN 'Outra_UF'								-- trata erro - ocorrencia de fora de MG
    	WHEN OCO.numero_latitude IS NULL THEN 'Invalido'							-- trata erro - ocorrencia sem latitude
        WHEN geo.situacao_codigo = 9 THEN 'Agua'									-- trata erro - ocorrencia dentro de curso d'água
       	WHEN geo.situacao_zona IS NULL THEN 'Erro_Processamento'					-- checa se restou alguma ocorrencia com erro
    	ELSE geo.situacao_zona
END AS situacao_zona,  
CAST(OCO.codigo_municipio AS INTEGER),                        -- Converte o código do município para número inteiro
OCO.nome_municipio,                                           -- Nome do município da ocorrência
OCO.tipo_logradouro_descricao,                                -- Tipo do logradouro (Rua, Avenida, etc)
OCO.logradouro_nome,                                          -- Nome do logradouro
OCO.numero_endereco,                                          -- Número do endereço
OCO.nome_bairro,                                              -- Nome do bairro
OCO.ocorrencia_uf,                                            -- Estado da ocorrência
REPLACE(CAST(OCO.numero_latitude AS STRING), ".", ",") AS local_latitude_formatado,
REPLACE(CAST(OCO.numero_longitude AS STRING), ".", ",") AS local_longitude_formatado,
CONCAT(
    SUBSTR(CAST(OCO.data_hora_fato AS STRING), 9, 2), '/',  -- Dia (posições 9-10)
    SUBSTR(CAST(OCO.data_hora_fato AS STRING), 6, 2), '/',  -- Mês (posições 6-7)
    SUBSTR(CAST(OCO.data_hora_fato AS STRING), 1, 4), ' ',  -- Ano (posições 1-4)
    SUBSTR(CAST(OCO.data_hora_fato AS STRING), 12, 8)       -- Hora (posições 12-19)
  ) AS data_hora_fato2,                   -- Converte a data/hora do fato para o padrão brasileiro
YEAR(OCO.data_hora_fato) AS ano,                           -- Ano do fato
MONTH(OCO.data_hora_fato) AS mes, -- Mês do fato
OCO.data_hora_fato,
OCO.nome_tipo_relatorio,                                   -- Tipo do relatório
OCO.digitador_sigla_orgao,                                  -- Sigla do órgão que registrou
geo.latitude_sirgas2000  AS numero_latitude,                                          -- Latitude da localização
geo.longitude_sirgas2000 AS numero_longitude,                                         -- Longitude da localização
geo.latitude_sirgas2000,				-- reprojeção da latitude de SAD69 para SIRGAS2000
geo.longitude_sirgas2000				-- reprojeção da longitude de SAD69 para SIRGAS2000
FROM db_bisp_reds_reporting.tb_ocorrencia OCO
LEFT JOIN db_bisp_reds_master.tb_local_unidade_area_pmmg LO ON OCO.id_local = LO.id_local 
LEFT JOIN db_bisp_reds_master.tb_ocorrencia_setores_geodata AS geo ON OCO.numero_ocorrencia = geo.numero_ocorrencia AND OCO.ocorrencia_uf = 'MG'	-- Tabela de apoio que compara as lat/long com os setores IBGE		
WHERE 1 = 1 
AND (                                                                            
    SELECT COUNT(DISTINCT envolvido.numero_envolvido)                           -- Conta o número de envolvidos distintos (evitando duplicatas)
    FROM db_bisp_reds_reporting.tb_envolvido_ocorrencia envolvido               
    WHERE envolvido.numero_ocorrencia = OCO.numero_ocorrencia                   
    AND (                                                                        -- Inicia uma condição composta para filtrar apenas envolvidos identificados
        envolvido.numero_cpf_cnpj IS NOT NULL                                   -- Filtra cpf/cnpj não nulo
        OR (                                                                     -- OU alternativa para identificação
            envolvido.numero_documento_id IS NOT NULL                           -- Filtra envolvidos com algum documento de identificação não nulo
            AND envolvido.tipo_documento_codigo = '0801'                        -- E que esse documento seja do tipo específico '0801' (RG)
        )
    )
) >= 3                                                                           -- Exige que existam pelo menos 3 envolvidos identificados na ocorrência
AND YEAR(OCO.data_hora_fato) >=2024
--AND OCO.data_hora_fato BETWEEN '2024-01-01 00:00:00.000' AND '2025-02-28 23:59:59.000'  -- Filtra ocorrências por período específico (todo o ano de 2024 até fevereiro/2025)
AND OCO.natureza_codigo IN ('A19006', 'A19007','A19008','A19009', 'A19010', 'A19011') -- Filtra ocorrências de naturezas A 19.006 - Reunião com os cadastrados na Rede de Vizinhos Protegidos; A 19.007 - Reunião com os cadastrados na Rede de Comerciantes Protegidos; A 19.008 - Reunião com os cadastrados na Rede de Bancos Protegidos; A 19.009 - Reunião com os cadastrados Rede Propriedades Rurais Protegidas; A 19.010 - Reunião com os cadastrados na Rede de Indústrias Protegidas; A 19.011 - Reunião com outras Redes de Proteção.
AND OCO.ocorrencia_uf = 'MG'                                                     -- Filtra apenas ocorrências do estado de Minas Gerais
AND OCO.digitador_sigla_orgao = 'PM'                                            -- Filtra ocorrências registradas pela Polícia Militar
AND OCO.unidade_responsavel_registro_nome NOT LIKE '%IND PE%'
 AND OCO.codigo_municipio IN (310340,311950,313400,314630,317160,311700,313330,314140,315217, -- '70 BPM'
							        310470,311080,311300,311545,312675,312680,313230,313270,313507,313700,313920,314490,314530,314535,314620,314850,315000,315240,316330,316555,316860, -- '19 BPM'
							       310090,310660,311370,312015,312705,313890,314430,315765,316670,317030, -- '24 CIA PM IND'
							       310170,310520,312245,312560,313470,313580,313600,313650,314055,314315,314675,315510,315660,315710,315810,316030,310100,310270,312235,314870) -- '44 BPM' 
AND OCO.nome_tipo_relatorio IN ('BOS', 'BOS AMPLO')                             -- Filtra por tipos específicos de relatórios BOS e BOS AMPLO
AND OCO.codigo_municipio in (310030, 310040, 310050, 310090, 310100, 310110, 310170, 310180, 310205, 315350, 310220, 310230, 310250, 310300, 310340, 310470, 310520, 310540, 310570, 310600, 310630, 310660, 310770, 310780, 310880, 310925, 310270, 311010, 311080, 311205, 311210, 311265, 311290, 311300, 311340, 311370, 311380, 311535, 311545, 311570, 311600, 311680, 311700, 311740, 311840, 311920, 311940, 311950, 312000, 312015, 312083, 312180, 312210, 312220, 312235, 312245, 312250, 312270, 312310, 312352, 312370, 312385, 312420, 312560, 312580, 312590, 312675, 312680, 312690, 312695, 312705, 312730, 312737, 312750, 312770, 312800, 312820, 312930, 313055, 313090, 313115, 313120, 313130, 313170, 313180, 313230, 313270, 313280, 313320, 313330, 313400, 313410, 313470, 313500, 313507, 313550, 313580, 313600, 313610, 313620, 313650, 313655, 313700, 313770, 313867, 313890, 313920, 313940, 313950, 313960, 314010, 314030, 314053, 314055, 314060, 317150, 314090, 314140, 314150, 314170, 314315, 314400, 314420, 314430, 314435, 314467, 314470, 314490, 314530, 314535, 314585, 314620, 314630, 314675, 314750, 314840, 314850, 314860, 314870, 314875, 314995, 315000, 315015, 315020, 315053, 315190, 315210, 315217, 315240, 315400, 315415, 315430, 315490, 315510, 315500, 315570, 315600, 315660, 315680, 315710, 315720, 315725, 315740, 315750, 315765, 315790, 315800, 315810, 315820, 315940, 315935, 315890, 315895, 316010, 316030, 316095, 316100, 316105, 316160, 316165, 316190, 316255, 316257, 316260, 316280, 316300, 316330, 316340, 316350, 316360, 316410, 316400, 316447, 316450, 316550, 316556, 316610, 316630, 316670, 316555, 316760, 316770, 316805, 316840, 316860, 316870, 316950, 317005, 317030, 317050, 317057, 317115, 317160, 317180, 317190) -- 3ª Cia PM MAmb
AND OCO.ind_estado IN ('F','R')                                                               -- Filtra ocorrências com indicador de estado 'F' (Fechado) e R(Pendente de Recibo)
AND OCO.unidade_responsavel_registro_nome LIKE '%3 CIA PM MAMB/BPM MAMB%'   ---- AND OCO.unidade_responsavel_registro_nome LIKE '%15 RPM%'   -- FILTRE PELO NOME DA UNIDADE RESPONSÁVEL PELO REGISTRO 
order by OCO.numero_ocorrencia
