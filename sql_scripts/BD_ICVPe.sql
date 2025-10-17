WITH LETALIDADE AS -- Define uma tabela temporária para filtrar ocorrências com letalidade policial
(
    SELECT -- Inicia a seleção dos campos para a CTE
        ENV.numero_ocorrencia, -- Seleciona o número identificador da ocorrência
        ENV.digitador_id_orgao, -- Seleciona o ID do órgão que digitou a ocorrência
        ENV.natureza_ocorrencia_codigo, -- Seleciona o código da natureza da ocorrência
        ENV.data_hora_fato, -- Seleciona a data e hora do fato
        ENV.ind_militar_policial_servico -- Seleciona o indicador se o militar estava em serviço
    FROM
        db_bisp_reds_reporting.tb_envolvido_ocorrencia ENV -- Define a tabela fonte dos dados de envolvidos
    WHERE
        1 = 1 -- Inicia as condições de filtro
        AND ENV.natureza_ocorrencia_codigo IN ('B01121', 'B01129') -- Filtra por natureza específica de letalidade (Homicídio)
        AND ENV.id_envolvimento IN (35, 36, 44) -- Filtra pelos tipos de envolvimento (autor, co-autor, suspeito)
        AND ENV.ind_militar_policial IS NOT DISTINCT FROM 'M' -- Filtra apenas militares
        AND ENV.ind_militar_policial_servico IS NOT DISTINCT FROM 'S' -- Filtra apenas militares em serviço
        AND YEAR(ENV.data_hora_fato) = 2025 --:ANO -- Filtra pelo ano parametrizado
        AND MONTH(ENV.data_hora_fato) >= 1 --:MESINICIAL -- Filtra a partir do mês inicial parametrizado
        AND MONTH(ENV.data_hora_fato) <= 12 --:MESFINAL -- Filtra até o mês final parametrizado
)
SELECT -- Inicia a seleção principal da query
    OCO.numero_ocorrencia, -- Número identificador da ocorrência
    geo.situacao_zona,
    ENV.envolvimento_codigo, -- Código do tipo de envolvimento na ocorrência
    ENV.envolvimento_descricao, -- Descrição do tipo de envolvimento
    ENV.numero_envolvido, -- Número identificador do envolvido
    ENV.nome_completo_envolvido, -- Nome completo do envolvido
    ENV.nome_mae, -- Nome da mãe do envolvido
    ENV.data_nascimento, -- Data de nascimento do envolvido
    ENV.ind_militar_policial_servico, -- Indicador se militar estava em serviço
    ENV.condicao_fisica_descricao, -- Descrição da condição física do envolvido
	CASE
		WHEN OCO.numero_ocorrencia IN ('2025-047221801-001') THEN 'B01121'
		ELSE ENV.natureza_ocorrencia_codigo
	END natureza_ocorrencia_codigo, -- Código da natureza da ocorrência
    ENV.natureza_ocorrencia_descricao, -- Descrição da natureza da ocorrência
    ENV.ind_consumado, -- Indicador se o crime foi consumado ou tentado
    CASE
        WHEN OCO.codigo_municipio IN (310090, 310100, 310170, 310270, 310340, 310470, 310520, 310660, 311080, 311300, 311370, 311545, 311700, 311950, 312015, 312235, 312245, 312560, 312675, 312680, 312705, 313230, 313270, 313330, 313400, 313470, 313507, 313580, 313600, 313650, 313700, 313890, 313920, 314055, 314140, 314315, 314430, 314490, 314530, 314535, 314620, 314630, 314675, 314850, 314870, 315000, 315217, 315240, 315510, 315660, 315710, 315765, 315810, 316030, 316330, 316555, 316670, 316860, 317030, 317160) THEN '15 RPM'
        ELSE 'OUTROS'
    END AS RPM_2024,
    CASE
        WHEN OCO.codigo_municipio IN (310470, 311080, 311300, 311545, 312675, 312680, 313230, 313270, 313507, 313700, 313920, 314490, 314530, 314535, 314620, 314850, 315000, 315240, 316330, 316555, 316860) THEN '19 BPM'
        ELSE 'OUTROS'
    END AS UEOP_2024,
    OCO.unidade_area_militar_codigo, -- Código da unidade militar da área
    OCO.unidade_area_militar_nome, -- Nome da unidade militar da área
    OCO.unidade_responsavel_registro_codigo, -- Código da unidade que registrou a ocorrência
    OCO.unidade_responsavel_registro_nome, -- Nome da unidade que registrou a ocorrência
    CAST(OCO.codigo_municipio AS INTEGER), -- Converte o código do município para número inteiro
    OCO.nome_municipio, -- Nome do município da ocorrência
    OCO.tipo_logradouro_descricao, -- Tipo do logradouro (Rua, Avenida, etc)
    OCO.logradouro_nome, -- Nome do logradouro
    OCO.numero_endereco, -- Número do endereço
    OCO.nome_bairro, -- Nome do bairro
    OCO.ocorrencia_uf, -- Estado da ocorrência
    OCO.numero_latitude, -- Latitude da localização
    OCO.numero_longitude, -- Longitude da localização
    OCO.data_hora_fato, -- Data e hora do fato
    YEAR(OCO.data_hora_fato) AS ano, -- Ano do fato
    MONTH(OCO.data_hora_fato) AS mes, -- Mês do fato
    OCO.nome_tipo_relatorio, -- Tipo do relatório
    OCO.digitador_sigla_orgao -- Sigla do órgão que registrou
FROM
    db_bisp_reds_reporting.tb_ocorrencia AS OCO -- Tabela principal de ocorrências
    INNER JOIN db_bisp_reds_reporting.tb_envolvido_ocorrencia AS ENV -- Join com tabela de envolvidos
    ON OCO.numero_ocorrencia = ENV.numero_ocorrencia
    LEFT JOIN LETALIDADE LET -- Join com a CTE de letalidade
    ON OCO.numero_ocorrencia = LET.numero_ocorrencia
    LEFT JOIN db_bisp_reds_master.tb_ocorrencia_setores_geodata AS geo ON OCO.numero_ocorrencia = geo.numero_ocorrencia AND OCO.ocorrencia_uf = 'MG'	-- Tabela de apoio que compara as lat/long com os setores IBGE
WHERE
    -- Bloco de condição para a ocorrência específica, que ignora todas as outras regras
    ( OCO.numero_ocorrencia IN ('2025-047221801-001') AND ENV.id_envolvimento IN (25, 32, 1097, 26, 27, 28, 872))
    OR -- OU a ocorrência atende a todas as regras gerais abaixo
    (
        LET.numero_ocorrencia IS NULL -- Exclui ocorrências que estão na CTE de letalidade
        AND ENV.id_envolvimento IN (25, 32, 1097, 26, 27, 28, 872) -- Filtra tipos específicos de envolvimento(Todos vitima)
        AND ENV.natureza_ocorrencia_codigo IN ('B01121', 'B01148', 'B02001', 'B01504') -- Filtra naturezas específicas(Homicídio,Sequestro e Cárcere Privado,Tortura, Feminicídio*)
        AND ENV.ind_consumado IN ('S', 'N') -- Filtra ocorrências consumadas e tentadas
        AND oco.numero_ocorrencia NOT IN ('2025-025232870-001', '2025-025472623-001')
        AND ENV.condicao_fisica_codigo IS DISTINCT FROM '0100' -- Exclui condição física específica(Fatal)
        AND OCO.ocorrencia_uf = 'MG' -- Filtra apenas ocorrências de Minas Gerais
        AND OCO.digitador_sigla_orgao IN ('PM', 'PC') -- Filtra registros da PM ou PC
        AND OCO.nome_tipo_relatorio IN ('POLICIAL', 'REFAP') -- Filtra tipos específicos de relatório
        AND YEAR(OCO.data_hora_fato) >= 2025 --:ANO -- Filtra pelo ano parametrizado
        AND MONTH(OCO.data_hora_fato) >= 1 --:MESINICIAL -- Filtra a partir do mês inicial
        AND MONTH(OCO.data_hora_fato) <= 12 --:MESFINAL -- Filtra até o mês final
        AND OCO.ind_estado = 'F' -- Filtra apenas ocorrências finalizadas
        -- AND OCO.codigo_municipio IN (310470, 311080, 311300, 311545, 312675, 312680, 313230, 313270, 313507, 313700, 313920, 314490, 314530, 314535, 314620, 314850, 315000, 315240, 316330, 316555, 316860) -- 19 BPM
        AND OCO.codigo_municipio in (310030, 310040, 310050, 310090, 310100, 310110, 310170, 310180, 310205, 315350, 310220, 310230, 310250, 310300, 310340, 310470, 310520, 310540, 310570, 310600, 310630, 310660, 310770, 310780, 310880, 310925, 310270, 311010, 311080, 311205, 311210, 311265, 311290, 311300, 311340, 311370, 311380, 311535, 311545, 311570, 311600, 311680, 311700, 311740, 311840, 311920, 311940, 311950, 312000, 312015, 312083, 312180, 312210, 312220, 312235, 312245, 312250, 312270, 312310, 312352, 312370, 312385, 312420, 312560, 312580, 312590, 312675, 312680, 312690, 312695, 312705, 312730, 312737, 312750, 312770, 312800, 312820, 312930, 313055, 313090, 313115, 313120, 313130, 313170, 313180, 313230, 313270, 313280, 313320, 313330, 313400, 313410, 313470, 313500, 313507, 313550, 313580, 313600, 313610, 313620, 313650, 313655, 313700, 313770, 313867, 313890, 313920, 313940, 313950, 313960, 314010, 314030, 314053, 314055, 314060, 317150, 314090, 314140, 314150, 314170, 314315, 314400, 314420, 314430, 314435, 314467, 314470, 314490, 314530, 314535, 314585, 314620, 314630, 314675, 314750, 314840, 314850, 314860, 314870, 314875, 314995, 315000, 315015, 315020, 315053, 315190, 315210, 315217, 315240, 315400, 315415, 315430, 315490, 315510, 315500, 315570, 315600, 315660, 315680, 315710, 315720, 315725, 315740, 315750, 315765, 315790, 315800, 315810, 315820, 315940, 315935, 315890, 315895, 316010, 316030, 316095, 316100, 316105, 316160, 316165, 316190, 316255, 316257, 316260, 316280, 316300, 316330, 316340, 316350, 316360, 316410, 316400, 316447, 316450, 316550, 316556, 316610, 316630, 316670, 316555, 316760, 316770, 316805, 316840, 316860, 316870, 316950, 317005, 317030, 317050, 317057, 317115, 317160, 317180, 317190) -- 3ª Cia PM MAmb
        -- PARA RESGATAR APENAS OS DADOS DOS MUNICÍPIOS SOB SUA RESPONSABILIDADE, REMOVA O COMENTÁRIO E ADICIONE O CÓDIGO DE MUNICIPIO DA SUA RESPONSABILIDADE. NO INÍCIO DO SCRIPT, É POSSÍVEL VERIFICAR ESSES CÓDIGOS, POR RPM E UEOP.
        -- AND OCO.unidade_area_militar_nome LIKE '%x BPM/x RPM%' -- Filtra pelo nome da unidade área militar
    )
ORDER BY -- Define a ordem de apresentação dos resultados
    RPM_2024, -- Primeiro por RPM
    UEOP_2024, -- Depois por UEOP
    OCO.data_hora_fato, -- Depois por data/hora
    OCO.numero_ocorrencia, -- Depois por número da ocorrência
    ENV.nome_completo_envolvido, -- Depois por nome do envolvido
    ENV.nome_mae, -- Depois por nome da mãe
    ENV.data_nascimento; -- Por fim, por data de nascimento