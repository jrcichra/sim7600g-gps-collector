CREATE TABLE `gps` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `hostname` varchar(255) NOT NULL,
  `record_timestamp` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `gps_timestamp` varchar(64) NOT NULL,
  `class` varchar(10) NOT NULL,
  `tag` varchar(255) NOT NULL,
  `device` varchar(255) NOT NULL,
  `mode` int NOT NULL,
  `ept` float NOT NULL,
  `lat` float NOT NULL,
  `lon` float NOT NULL,
  `alt` float NOT NULL,
  `epx` float NOT NULL,
  `epy` float NOT NULL,
  `epv` float NOT NULL,
  `track` float NOT NULL,
  `speed` float NOT NULL,
  `climb` float NOT NULL,
  `epd` float NOT NULL,
  `eps` float NOT NULL,
  `epc` float NOT NULL,
  `v_gps_timestamp` timestamp(6) GENERATED ALWAYS AS (
    (case
        when (locate(_utf8mb4'.',`gps_timestamp`) = 0) then convert_tz(str_to_date(`gps_timestamp`,_utf8mb4'%Y-%m-%dT%H:%i:%sZ'),_utf8mb4'Zulu',_utf8mb4'America/New_York')
        when (locate(_utf8mb4'.',`gps_timestamp`) <> 0) then convert_tz(str_to_date(`gps_timestamp`,_utf8mb4'%Y-%m-%dT%H:%i:%s.%fZ'),_utf8mb4'Zulu',_utf8mb4'America/New_York')
    end)
    ) VIRTUAL,
  PRIMARY KEY (`id`),
  KEY `gps_record_timestamp_IDX` (`record_timestamp`) USING BTREE,
  KEY `indx_v_gps_timestamp` (`v_gps_timestamp`)
)

