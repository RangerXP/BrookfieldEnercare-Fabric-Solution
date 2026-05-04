-- ============================================================
-- ENERCARE DEMO SEED DATA
-- Realistic Ontario energy-services sample data
--
-- Data references:
--   Postal codes   : Statistics Canada Forward Sortation Areas (Ontario)
--   Equipment makes: publicly listed Enercare product partners
--   Gas distributor: Enbridge Gas (ON default), Union Gas (SW ON)
--   Hydro utility  : Toronto Hydro, Hydro One, Alectra Utilities
--   Product pricing: Enercare public rate card (approximated)
--
-- Run after: 00_demo_schema_and_headers.sql
-- ============================================================

SET NOCOUNT ON;
GO

-- ============================================================
-- PRODUCTS  (10 rows — Enercare-style catalogue)
-- ============================================================
INSERT INTO demo.products (product_code, product_name, product_category, billing_frequency, base_price, is_active, effective_date)
VALUES
  ('WH-GAS-STD',  'Natural Gas Water Heater – Standard Rental',  'Rental',     'Monthly',  24.99, 1, '2020-01-01'),
  ('WH-GAS-PREM', 'Natural Gas Water Heater – Premium Rental',   'Rental',     'Monthly',  34.99, 1, '2020-01-01'),
  ('WH-ELEC-STD', 'Electric Water Heater – Standard Rental',     'Rental',     'Monthly',  19.99, 1, '2020-01-01'),
  ('PP-HEAT',     'Heating Protection Plus',                     'Protection', 'Monthly',  39.99, 1, '2019-01-01'),
  ('PP-COOL',     'Cooling Advantage Plan',                      'Protection', 'Monthly',  24.99, 1, '2019-01-01'),
  ('PP-PLUMB',    'Plumbing Protection Plan',                    'Protection', 'Monthly',  14.99, 1, '2019-01-01'),
  ('PP-ELEC-HM',  'Electrical Home Protection',                  'Protection', 'Monthly',  19.99, 1, '2021-06-01'),
  ('SH-BASIC',    'Smart Home Essentials',                       'SmartHome',  'Monthly',  29.99, 1, '2022-01-01'),
  ('SH-PREM',     'Smart Home Premium',                          'SmartHome',  'Monthly',  59.99, 1, '2022-01-01'),
  ('ECOBEE-INST', 'ecobee Smart Thermostat – Supply & Install',  'SmartHome',  'OneTime', 249.00, 1, '2022-03-01');
GO


-- ============================================================
-- CUSTOMERS  (50 rows — Ontario residential & commercial mix)
-- Postal codes are real Ontario FSAs (Statistics Canada)
-- ============================================================
INSERT INTO demo.customers (account_number, first_name, last_name, email, phone, customer_type, status, city, province, postal_code, created_date)
VALUES
  ('EC-0001001','James',     'Whitmore',    'j.whitmore@email.ca',      '416-555-0101', 'Residential', 'Active',   'Toronto',         'ON', 'M4K 1A1', '2018-03-15'),
  ('EC-0001002','Sophie',    'Tremblay',    'stremblay@outlook.com',    '416-555-0102', 'Residential', 'Active',   'Toronto',         'ON', 'M6G 3H2', '2019-06-20'),
  ('EC-0001003','Raj',       'Patel',       'rajpatel@gmail.com',       '905-555-0103', 'Residential', 'Active',   'Mississauga',     'ON', 'L5B 2C4', '2017-11-08'),
  ('EC-0001004','Mei',       'Chen',        'mei.chen@hotmail.com',     '905-555-0104', 'Residential', 'Active',   'Markham',         'ON', 'L3R 4G5', '2020-02-14'),
  ('EC-0001005','Patrick',   'OBrien',      'pobrien@rogers.ca',        '416-555-0105', 'Residential', 'Active',   'Etobicoke',       'ON', 'M9C 2A1', '2016-08-22'),
  ('EC-0001006','Amara',     'Okafor',      'amara.okafor@gmail.com',   '647-555-0106', 'Residential', 'Active',   'Toronto',         'ON', 'M1B 3W2', '2021-05-10'),
  ('EC-0001007','Yuki',      'Nakamura',    'yukinaka@yahoo.ca',        '905-555-0107', 'Residential', 'Active',   'Oakville',        'ON', 'L6H 5N3', '2019-09-03'),
  ('EC-0001008','Carlos',    'Morales',     'carlos.m@gmail.com',       '905-555-0108', 'Residential', 'Active',   'Brampton',        'ON', 'L6Y 4K8', '2020-07-17'),
  ('EC-0001009','Diana',     'Leclair',     'dleclair@sympatico.ca',    '613-555-0109', 'Residential', 'Active',   'Ottawa',          'ON', 'K1S 5B6', '2018-01-30'),
  ('EC-0001010','Samuel',    'Wright',      'samwright@live.ca',        '905-555-0110', 'Residential', 'Active',   'Hamilton',        'ON', 'L8S 2J9', '2015-04-12'),
  ('EC-0001011','Fatima',    'Al-Rashid',   'f.alrashid@bell.net',      '416-555-0111', 'Residential', 'Active',   'Scarborough',     'ON', 'M1P 2V7', '2022-03-08'),
  ('EC-0001012','Andrew',    'MacLeod',     'amacleod@cogeco.ca',       '905-555-0112', 'Residential', 'Active',   'Burlington',      'ON', 'L7R 3N2', '2017-07-25'),
  ('EC-0001013','Priya',     'Sharma',      'priya.sharma@gmail.com',   '905-555-0113', 'Residential', 'Active',   'Mississauga',     'ON', 'L5M 6K4', '2021-11-14'),
  ('EC-0001014','Thomas',    'Beaulieu',    'tbeaulieu@videotron.ca',   '613-555-0114', 'Residential', 'Active',   'Kanata',          'ON', 'K2K 1X4', '2016-12-05'),
  ('EC-0001015','Grace',     'Kim',         'gracekim@naver.com',       '416-555-0115', 'Residential', 'Active',   'North York',      'ON', 'M2N 5P2', '2023-01-19'),
  ('EC-0001016','Michael',   'Dupont',      'mdupont@gmail.com',        '613-555-0116', 'Residential', 'Active',   'Orleans',         'ON', 'K4A 3T6', '2019-08-11'),
  ('EC-0001017','Sandra',    'Nielsen',     'snielsen@outlook.com',     '905-555-0117', 'Residential', 'Active',   'Ajax',            'ON', 'L1Z 1N3', '2020-10-29'),
  ('EC-0001018','Kwame',     'Asante',      'kwame.asante@hotmail.com', '416-555-0118', 'Residential', 'Active',   'Toronto',         'ON', 'M3H 4B7', '2018-06-03'),
  ('EC-0001019','Isabelle',  'Gagnon',      'igagnon@bell.ca',          '613-555-0119', 'Residential', 'Active',   'Ottawa',          'ON', 'K2B 7W3', '2017-03-21'),
  ('EC-0001020','Robert',    'Tanaka',      'rtanaka@gmail.com',        '905-555-0120', 'Residential', 'Active',   'Oshawa',          'ON', 'L1H 3Z2', '2015-09-14'),
  ('EC-0001021','Nadia',     'Kowalski',    'nkowalski@rogers.ca',      '416-555-0121', 'Residential', 'Inactive', 'Etobicoke',       'ON', 'M9W 1P4', '2014-02-07'),
  ('EC-0001022','Ivan',      'Petrov',      'ipetrov@live.com',         '905-555-0122', 'Residential', 'Active',   'Whitby',          'ON', 'L1N 5T8', '2021-04-16'),
  ('EC-0001023','Helene',    'Bouchard',    'hbouchard@laposte.net',    '613-555-0123', 'Residential', 'Active',   'Gatineau',        'ON', 'J8Y 1T4', '2022-08-30'),
  ('EC-0001024','Marcus',    'Thompson',    'm.thompson@gmail.com',     '647-555-0124', 'Residential', 'Active',   'Vaughan',         'ON', 'L4L 8B3', '2019-12-12'),
  ('EC-0001025','Lin',       'Zhang',       'lin.zhang@yahoo.ca',       '905-555-0125', 'Residential', 'Active',   'Richmond Hill',   'ON', 'L4C 9K5', '2020-05-07'),
  ('EC-0001026','Olivia',    'Murphy',      'omurphy@cogeco.ca',        '905-555-0126', 'Residential', 'Active',   'Kingston',        'ON', 'K7L 4V2', '2016-07-18'),
  ('EC-0001027','Hassan',    'Ibrahim',     'hibrahim@hotmail.ca',      '416-555-0127', 'Residential', 'Active',   'Scarborough',     'ON', 'M1T 3N6', '2023-03-22'),
  ('EC-0001028','Claire',    'Fontaine',    'cfontaine@sympatico.ca',   '519-555-0128', 'Residential', 'Active',   'London',          'ON', 'N6A 4C9', '2018-10-01'),
  ('EC-0001029','Derek',     'Sinclair',    'dsinclair@bell.net',       '905-555-0129', 'Residential', 'Active',   'Barrie',          'ON', 'L4N 7P3', '2017-05-14'),
  ('EC-0001030','Yolanda',   'Santos',      'ysantos@rogers.ca',        '416-555-0130', 'Residential', 'Active',   'Toronto',         'ON', 'M6R 1E8', '2021-07-09'),
  ('EC-0001031','Nathan',    'Bergeron',    'nbergeron@videotron.ca',   '613-555-0131', 'Residential', 'Active',   'Ottawa',          'ON', 'K1V 9B4', '2019-02-25'),
  ('EC-0001032','Anita',     'Verma',       'averma@gmail.com',         '905-555-0132', 'Residential', 'Active',   'Mississauga',     'ON', 'L4Z 3C7', '2022-01-17'),
  ('EC-0001033','Scott',     'Henderson',   'shenderson@outlook.com',   '905-555-0133', 'Residential', 'Active',   'Newmarket',       'ON', 'L3Y 8C2', '2016-04-03'),
  ('EC-0001034','Zara',      'Ali',         'zali@hotmail.com',         '416-555-0134', 'Residential', 'Active',   'North York',      'ON', 'M2M 2T9', '2020-11-11'),
  ('EC-0001035','Eric',      'Larochelle',  'elarochelle@bell.ca',      '613-555-0135', 'Residential', 'Active',   'Ottawa',          'ON', 'K2P 1T3', '2018-08-27'),
  ('EC-0001036','Vanessa',   'Castillo',    'vcastillo@gmail.com',      '905-555-0136', 'Residential', 'Active',   'Pickering',       'ON', 'L1V 3X9', '2021-09-05'),
  ('EC-0001037','Brendan',   'Walsh',       'bwalsh@rogers.ca',         '519-555-0137', 'Residential', 'Active',   'Guelph',          'ON', 'N1G 5A8', '2017-01-23'),
  ('EC-0001038','Mei-Ling',  'Lau',         'meilau@yahoo.ca',          '905-555-0138', 'Residential', 'Active',   'Markham',         'ON', 'L3S 4K2', '2019-07-14'),
  ('EC-0001039','Jerome',    'Fontaine',    'jfontaine@cogeco.ca',      '613-555-0139', 'Residential', 'Active',   'Ottawa',          'ON', 'K2H 8P7', '2020-03-30'),
  ('EC-0001040','Angela',    'Kowalczyk',   'akowalczyk@gmail.com',     '416-555-0140', 'Residential', 'Active',   'Toronto',         'ON', 'M5V 2H1', '2022-06-15'),
  -- Commercial accounts
  ('EC-0002001','Maple Leaf Properties',  NULL, 'accounts@mlproperties.ca',  '416-555-0201', 'Commercial', 'Active', 'Toronto',     'ON', 'M5H 2N2', '2015-11-01'),
  ('EC-0002002','Sunrise Plazas Inc',     NULL, 'facilities@sunriseplazas.ca','905-555-0202', 'Commercial', 'Active', 'Mississauga', 'ON', 'L4W 1S9', '2016-03-14'),
  ('EC-0002003','Lakeview Medical Centre',NULL, 'admin@lakeviewmed.ca',      '905-555-0203', 'Commercial', 'Active', 'Burlington',  'ON', 'L7L 6A4', '2017-09-22'),
  ('EC-0002004','Cornerstone Realty',     NULL, 'info@cstonerealty.ca',      '613-555-0204', 'Commercial', 'Active', 'Ottawa',      'ON', 'K1G 4K3', '2018-05-16'),
  ('EC-0002005','Northgate Logistics',    NULL, 'ops@northgatelogis.ca',     '905-555-0205', 'Commercial', 'Active', 'Brampton',    'ON', 'L6T 5A9', '2019-10-07'),
  -- Multi-unit residential
  ('EC-0003001','Harbourview Condos',     NULL, 'manager@hvcondos.ca',       '416-555-0301', 'MUR',        'Active', 'Toronto',     'ON', 'M5J 2T3', '2016-06-01'),
  ('EC-0003002','Riverside Gardens',      NULL, 'super@riversidegardens.ca', '613-555-0302', 'MUR',        'Active', 'Ottawa',      'ON', 'K1K 2Z8', '2017-02-28'),
  ('EC-0003003','Oakwood Manor Rentals',  NULL, 'office@oakwoodmanor.ca',    '905-555-0303', 'MUR',        'Active', 'Hamilton',    'ON', 'L8P 4V7', '2018-07-19'),
  ('EC-0003004','Greenfield Residences',  NULL, 'mgmt@greenfieldres.ca',     '905-555-0304', 'MUR',        'Active', 'Markham',     'ON', 'L3R 0J4', '2020-01-15'),
  ('EC-0003005','Skyline Towers',         NULL, 'admin@skylinetowers.ca',    '416-555-0305', 'MUR',        'Active', 'North York',  'ON', 'M2J 1L8', '2021-03-10');
GO


-- ============================================================
-- SERVICE ACCOUNTS  (70 rows)
-- ============================================================
INSERT INTO demo.service_accounts (customer_id, account_number, utility_type, rate_class, distributor, status, service_address, city, postal_code, opened_date)
VALUES
  -- Residential customers — one or two accounts each
  (1,  'SA-1001-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '142 Broadview Ave',     'Toronto',       'M4K 1A1', '2018-03-15'),
  (1,  'SA-1001-WH',   'Water Heater',  'Residential', 'Enbridge Gas',   'Active', '142 Broadview Ave',     'Toronto',       'M4K 1A1', '2018-03-15'),
  (2,  'SA-1002-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '87 Christie St',        'Toronto',       'M6G 3H2', '2019-06-20'),
  (3,  'SA-1003-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '3245 Hurontario St',    'Mississauga',   'L5B 2C4', '2017-11-08'),
  (3,  'SA-1003-COOL', 'HVAC',          'Residential', 'Enbridge Gas',   'Active', '3245 Hurontario St',    'Mississauga',   'L5B 2C4', '2019-05-01'),
  (4,  'SA-1004-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '74 Warden Ave',         'Markham',       'L3R 4G5', '2020-02-14'),
  (5,  'SA-1005-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '1891 Kipling Ave',      'Etobicoke',     'M9C 2A1', '2016-08-22'),
  (5,  'SA-1005-WH',   'Water Heater',  'Residential', 'Enbridge Gas',   'Active', '1891 Kipling Ave',      'Etobicoke',     'M9C 2A1', '2016-08-22'),
  (6,  'SA-1006-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '28 Morningside Ave',    'Scarborough',   'M1B 3W2', '2021-05-10'),
  (7,  'SA-1007-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '512 Trafalgar Rd',      'Oakville',      'L6H 5N3', '2019-09-03'),
  (7,  'SA-1007-COOL', 'HVAC',          'Residential', 'Enbridge Gas',   'Active', '512 Trafalgar Rd',      'Oakville',      'L6H 5N3', '2021-06-15'),
  (8,  'SA-1008-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '88 Sandalwood Pkwy',    'Brampton',      'L6Y 4K8', '2020-07-17'),
  (9,  'SA-1009-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '220 Glebe Ave',         'Ottawa',        'K1S 5B6', '2018-01-30'),
  (10, 'SA-1010-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '55 Garth St',           'Hamilton',      'L8S 2J9', '2015-04-12'),
  (10, 'SA-1010-WH',   'Water Heater',  'Residential', 'Enbridge Gas',   'Active', '55 Garth St',           'Hamilton',      'L8S 2J9', '2015-04-12'),
  (11, 'SA-1011-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '95 Ellesmere Rd',       'Scarborough',   'M1P 2V7', '2022-03-08'),
  (12, 'SA-1012-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '781 Plains Rd E',       'Burlington',    'L7R 3N2', '2017-07-25'),
  (12, 'SA-1012-COOL', 'HVAC',          'Residential', 'Enbridge Gas',   'Active', '781 Plains Rd E',       'Burlington',    'L7R 3N2', '2020-04-01'),
  (13, 'SA-1013-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '4060 Creditview Rd',    'Mississauga',   'L5M 6K4', '2021-11-14'),
  (14, 'SA-1014-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '98 Hazeldean Rd',       'Kanata',        'K2K 1X4', '2016-12-05'),
  (15, 'SA-1015-ELEC', 'Electricity',   'Residential', 'Hydro One',      'Active', '310 Sheppard Ave E',    'North York',    'M2N 5P2', '2023-01-19'),
  (16, 'SA-1016-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '2150 Tenth Line Rd',    'Orleans',       'K4A 3T6', '2019-08-11'),
  (17, 'SA-1017-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '35 Rossland Rd W',      'Ajax',          'L1Z 1N3', '2020-10-29'),
  (18, 'SA-1018-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '67 Viewmount Ave',      'Toronto',       'M3H 4B7', '2018-06-03'),
  (19, 'SA-1019-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '440 Woodroffe Ave',     'Ottawa',        'K2B 7W3', '2017-03-21'),
  (20, 'SA-1020-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '219 Simcoe St S',       'Oshawa',        'L1H 3Z2', '2015-09-14'),
  (21, 'SA-1021-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Closed', '40 Burnhamthorpe Rd',   'Etobicoke',     'M9W 1P4', '2014-02-07'),
  (22, 'SA-1022-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '110 Brock St N',        'Whitby',        'L1N 5T8', '2021-04-16'),
  (23, 'SA-1023-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '355 Principale St',     'Gatineau',      'J8Y 1T4', '2022-08-30'),
  (24, 'SA-1024-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '9820 Keele St',         'Vaughan',       'L4L 8B3', '2019-12-12'),
  (25, 'SA-1025-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '300 Major Mackenzie W', 'Richmond Hill', 'L4C 9K5', '2020-05-07'),
  (26, 'SA-1026-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '88 Princess St',        'Kingston',      'K7L 4V2', '2016-07-18'),
  (27, 'SA-1027-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '55 Pharmacy Ave',       'Scarborough',   'M1T 3N6', '2023-03-22'),
  (28, 'SA-1028-GAS',  'Natural Gas',   'Residential', 'Union Gas',      'Active', '745 Wellington Rd S',   'London',        'N6A 4C9', '2018-10-01'),
  (29, 'SA-1029-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '430 Mapleview Dr W',    'Barrie',        'L4N 7P3', '2017-05-14'),
  (30, 'SA-1030-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '1180 Bloor St W',       'Toronto',       'M6R 1E8', '2021-07-09'),
  (31, 'SA-1031-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '1465 Merivale Rd',      'Ottawa',        'K1V 9B4', '2019-02-25'),
  (32, 'SA-1032-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '900 Rathburn Rd W',     'Mississauga',   'L4Z 3C7', '2022-01-17'),
  (33, 'SA-1033-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '17555 Yonge St',        'Newmarket',     'L3Y 8C2', '2016-04-03'),
  (34, 'SA-1034-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '4100 Bathurst St',      'North York',    'M2M 2T9', '2020-11-11'),
  (35, 'SA-1035-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '230 Elgin St',          'Ottawa',        'K2P 1T3', '2018-08-27'),
  (36, 'SA-1036-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '1215 Kingston Rd',      'Pickering',     'L1V 3X9', '2021-09-05'),
  (37, 'SA-1037-GAS',  'Natural Gas',   'Residential', 'Union Gas',      'Active', '99 Stone Rd W',         'Guelph',        'N1G 5A8', '2017-01-23'),
  (38, 'SA-1038-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '7700 Kennedy Rd',       'Markham',       'L3S 4K2', '2019-07-14'),
  (39, 'SA-1039-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '1547 Woodward Dr',      'Ottawa',        'K2H 8P7', '2020-03-30'),
  (40, 'SA-1040-GAS',  'Natural Gas',   'Residential', 'Enbridge Gas',   'Active', '555 King St W',         'Toronto',       'M5V 2H1', '2022-06-15'),
  -- Commercial accounts
  (41, 'SA-2001-COM',  'Natural Gas',   'General Commercial', 'Enbridge Gas',   'Active', '100 King St W Ste 800', 'Toronto',     'M5H 2N2', '2015-11-01'),
  (42, 'SA-2002-COM',  'Natural Gas',   'General Commercial', 'Enbridge Gas',   'Active', '5800 Dixie Rd',         'Mississauga', 'L4W 1S9', '2016-03-14'),
  (43, 'SA-2003-COM',  'Natural Gas',   'General Commercial', 'Enbridge Gas',   'Active', '3200 Harvester Rd',     'Burlington',  'L7L 6A4', '2017-09-22'),
  (44, 'SA-2004-COM',  'Natural Gas',   'General Commercial', 'Enbridge Gas',   'Active', '280 Slater St',         'Ottawa',      'K1G 4K3', '2018-05-16'),
  (45, 'SA-2005-COM',  'Natural Gas',   'General Commercial', 'Enbridge Gas',   'Active', '10 Parkhurst Dr',       'Brampton',    'L6T 5A9', '2019-10-07'),
  -- MUR accounts (multiple units share one service account)
  (46, 'SA-3001-MUR',  'Natural Gas',   'Residential',        'Enbridge Gas',   'Active', '300 Queens Quay W',     'Toronto',     'M5J 2T3', '2016-06-01'),
  (47, 'SA-3002-MUR',  'Natural Gas',   'Residential',        'Enbridge Gas',   'Active', '200 Tremblay Rd',       'Ottawa',      'K1K 2Z8', '2017-02-28'),
  (48, 'SA-3003-MUR',  'Natural Gas',   'Residential',        'Enbridge Gas',   'Active', '112 James St N',        'Hamilton',    'L8P 4V7', '2018-07-19'),
  (49, 'SA-3004-MUR',  'Natural Gas',   'Residential',        'Enbridge Gas',   'Active', '9800 McCowan Rd',       'Markham',     'L3R 0J4', '2020-01-15'),
  (50, 'SA-3005-MUR',  'Natural Gas',   'Residential',        'Enbridge Gas',   'Active', '4789 Yonge St',         'North York',  'M2J 1L8', '2021-03-10');
GO


-- ============================================================
-- EQUIPMENT REGISTRY  (65 rows)
-- Makes: Rheem, Bradford White, A.O. Smith (water heaters)
--        Lennox, Carrier, York, Goodman (HVAC)
--        ecobee, Honeywell Home (thermostats)
-- ============================================================
INSERT INTO demo.equipment_registry (service_account_id, equipment_type, make, model, serial_number, ownership_type, fuel_type, install_date, warranty_expiry, status)
SELECT sa.service_account_id, eq.*
FROM (VALUES
  -- Residential gas water heaters
  ('SA-1001-WH',  'Water Heater',   'Rheem',           'Performance Plus 40G',  'RH2019-041847', 'Rental',  'Natural Gas', '2019-03-22', '2024-03-22', 'Active'),
  ('SA-1005-WH',  'Water Heater',   'Bradford White',  'RG250H6-1',             'BW2016-088231', 'Rental',  'Natural Gas', '2016-09-14', '2021-09-14', 'Active'),
  ('SA-1010-WH',  'Water Heater',   'A.O. Smith',      'ProMax 50G',            'AO2015-059944', 'Rental',  'Natural Gas', '2015-05-20', '2020-05-20', 'Active'),
  -- Residential furnaces
  ('SA-1001-GAS', 'Furnace',        'Lennox',          'EL296V',                'LX2018-112034', 'Customer-Owned', 'Natural Gas', '2018-11-05', '2028-11-05', 'Active'),
  ('SA-1003-GAS', 'Furnace',        'Carrier',         'Performance 96',        'CR2017-203811', 'Customer-Owned', 'Natural Gas', '2017-12-10', '2027-12-10', 'Active'),
  ('SA-1005-GAS', 'Furnace',        'York',            'TM9V',                  'YK2016-094520', 'Customer-Owned', 'Natural Gas', '2016-10-03', '2026-10-03', 'Active'),
  ('SA-1007-GAS', 'Furnace',        'Goodman',         'GMSS960603BN',          'GD2019-187623', 'Customer-Owned', 'Natural Gas', '2019-10-17', '2024-10-17', 'Active'),
  ('SA-1009-GAS', 'Furnace',        'Lennox',          'SLP99V',                'LX2018-208410', 'Customer-Owned', 'Natural Gas', '2018-02-14', '2028-02-14', 'Active'),
  ('SA-1010-GAS', 'Furnace',        'Carrier',         'Infinity 98',           'CR2015-094017', 'Customer-Owned', 'Natural Gas', '2015-06-08', '2025-06-08', 'Active'),
  ('SA-1012-GAS', 'Furnace',        'Lennox',          'ML296V',                'LX2017-301755', 'Customer-Owned', 'Natural Gas', '2017-08-22', '2022-08-22', 'Active'),
  ('SA-1014-GAS', 'Furnace',        'York',            'YP9C',                  'YK2016-204319', 'Customer-Owned', 'Natural Gas', '2016-12-30', '2021-12-30', 'Active'),
  ('SA-1016-GAS', 'Furnace',        'Goodman',         'GCVC960604CX',          'GD2019-394812', 'Customer-Owned', 'Natural Gas', '2019-09-01', '2024-09-01', 'Active'),
  ('SA-1020-GAS', 'Furnace',        'Lennox',          'EL296V',                'LX2015-105522', 'Customer-Owned', 'Natural Gas', '2015-10-15', '2020-10-15', 'Active'),
  -- Central AC units
  ('SA-1001-GAS', 'Central AC',     'Lennox',          'XC21',                  'LX2018-AC4420', 'Customer-Owned', 'Electric',    '2018-06-01', '2028-06-01', 'Active'),
  ('SA-1003-COOL','Central AC',     'Carrier',         'Infinity 21',           'CR2019-AC8811', 'Customer-Owned', 'Electric',    '2019-05-15', '2029-05-15', 'Active'),
  ('SA-1005-GAS', 'Central AC',     'York',            'YXV',                   'YK2016-AC3120', 'Customer-Owned', 'Electric',    '2016-05-28', '2026-05-28', 'Active'),
  ('SA-1007-COOL','Central AC',     'Lennox',          'SCA060H4B',             'LX2021-AC9920', 'Customer-Owned', 'Electric',    '2021-06-20', '2031-06-20', 'Active'),
  ('SA-1012-COOL','Central AC',     'Goodman',         'GSX140481',             'GD2020-AC7741', 'Customer-Owned', 'Electric',    '2020-05-10', '2025-05-10', 'Active'),
  -- Heat pumps
  ('SA-1015-ELEC','Heat Pump',      'Carrier',         'Infinity 20 GREENSPEED','CR2023-HP0041', 'Customer-Owned', 'Electric',    '2023-02-10', '2033-02-10', 'Active'),
  ('SA-1040-GAS', 'Heat Pump',      'Lennox',          'XP25',                  'LX2022-HP8811', 'Customer-Owned', 'Electric',    '2022-07-18', '2032-07-18', 'Active'),
  -- Smart thermostats
  ('SA-1001-GAS', 'Smart Thermostat','ecobee',         'SmartThermostat Premium','EB2022-TH3341','Customer-Owned', NULL,          '2022-04-05', '2027-04-05', 'Active'),
  ('SA-1003-GAS', 'Smart Thermostat','ecobee',         'SmartThermostat Enhanced','EB2021-TH1192','Customer-Owned',NULL,          '2021-09-12', '2026-09-12', 'Active'),
  ('SA-1007-GAS', 'Smart Thermostat','Honeywell Home', 'T9 Smart Thermostat',   'HW2020-TH5512', 'Customer-Owned', NULL,          '2020-11-03', '2025-11-03', 'Active'),
  ('SA-1009-GAS', 'Smart Thermostat','ecobee',         'SmartThermostat Premium','EB2023-TH8871','Customer-Owned', NULL,          '2023-01-28', '2028-01-28', 'Active'),
  ('SA-1012-GAS', 'Smart Thermostat','Honeywell Home', 'T6 Pro Smart Thermostat','HW2019-TH2219','Customer-Owned', NULL,          '2019-11-15', '2024-11-15', 'Active'),
  -- MUR building equipment (higher counts per account)
  ('SA-3001-MUR', 'Water Heater',   'Rheem',           'Marathon 85G Electric', 'RH2016-MUR001','Rental',  'Electric',    '2016-07-15', '2021-07-15', 'Active'),
  ('SA-3001-MUR', 'Furnace',        'Carrier',         'Performance 80',        'CR2016-MUR002','Rental',  'Natural Gas', '2016-07-15', '2026-07-15', 'Active'),
  ('SA-3002-MUR', 'Water Heater',   'Bradford White',  'RE280T6-1NCWW',         'BW2017-MUR001','Rental',  'Electric',    '2017-03-10', '2022-03-10', 'Active'),
  ('SA-3002-MUR', 'Furnace',        'Lennox',          'ML296V',                'LX2017-MUR002','Rental',  'Natural Gas', '2017-03-10', '2027-03-10', 'Active'),
  ('SA-3003-MUR', 'Water Heater',   'A.O. Smith',      'PROMO 50',              'AO2018-MUR001','Rental',  'Natural Gas', '2018-08-20', '2023-08-20', 'Active'),
  ('SA-3004-MUR', 'Water Heater',   'Rheem',           'Classic 50G',           'RH2020-MUR001','Rental',  'Natural Gas', '2020-02-05', '2025-02-05', 'Active'),
  ('SA-3005-MUR', 'Water Heater',   'Bradford White',  'RG240H6-1',             'BW2021-MUR001','Rental',  'Natural Gas', '2021-04-01', '2026-04-01', 'Active'),
  ('SA-3005-MUR', 'Central AC',     'York',            'YZV',                   'YK2021-MUR002','Rental',  'Electric',    '2021-05-12', '2031-05-12', 'Active'),
  -- Commercial equipment
  ('SA-2001-COM', 'Water Heater',   'Rheem',           'Commercial 100G Gas',   'RH2015-COM001','Rental',  'Natural Gas', '2015-11-15', '2020-11-15', 'Active'),
  ('SA-2002-COM', 'Furnace',        'Carrier',         'ComfortHeat 48SS',      'CR2016-COM001','Customer-Owned','Natural Gas','2016-04-01','2026-04-01', 'Active'),
  ('SA-2003-COM', 'Water Heater',   'A.O. Smith',      'ProLine 80G',           'AO2017-COM001','Rental',  'Natural Gas', '2017-10-10', '2022-10-10', 'Active'),
  ('SA-2004-COM', 'Furnace',        'Lennox',          'LCH240H4B',             'LX2018-COM001','Customer-Owned','Natural Gas','2018-06-01','2028-06-01', 'Active'),
  ('SA-2005-COM', 'Water Heater',   'Bradford White',  'MI50L6-1NCWWL',        'BW2019-COM001','Rental',  'Natural Gas', '2019-10-20', '2024-10-20', 'Active')
) eq(account_number, equipment_type, make, model, serial_number, ownership_type, fuel_type, install_date, warranty_expiry, status)
JOIN demo.service_accounts sa ON sa.account_number = eq.account_number;
GO


-- ============================================================
-- CONTRACTS  (68 rows)
-- ============================================================
INSERT INTO demo.contracts (service_account_id, product_id, contract_status, start_date, end_date, monthly_amount, auto_renew, cancellation_date, cancellation_reason)
SELECT sa.service_account_id, p.product_id, c.*
FROM (VALUES
  -- Water heater rentals
  ('SA-1001-WH',  'WH-GAS-STD',  'Active',    '2018-03-15', NULL,         24.99, 1, NULL, NULL),
  ('SA-1005-WH',  'WH-GAS-PREM', 'Active',    '2016-08-22', NULL,         34.99, 1, NULL, NULL),
  ('SA-1010-WH',  'WH-GAS-STD',  'Active',    '2015-04-12', NULL,         24.99, 1, NULL, NULL),
  ('SA-3001-MUR', 'WH-ELEC-STD', 'Active',    '2016-06-01', NULL,         19.99, 1, NULL, NULL),
  ('SA-3002-MUR', 'WH-ELEC-STD', 'Active',    '2017-02-28', NULL,         19.99, 1, NULL, NULL),
  ('SA-3003-MUR', 'WH-GAS-STD',  'Active',    '2018-07-19', NULL,         24.99, 1, NULL, NULL),
  ('SA-3004-MUR', 'WH-GAS-STD',  'Active',    '2020-01-15', NULL,         24.99, 1, NULL, NULL),
  ('SA-3005-MUR', 'WH-GAS-PREM', 'Active',    '2021-03-10', NULL,         34.99, 1, NULL, NULL),
  ('SA-2001-COM', 'WH-GAS-PREM', 'Active',    '2015-11-01', NULL,         34.99, 1, NULL, NULL),
  ('SA-2003-COM', 'WH-GAS-STD',  'Active',    '2017-09-22', NULL,         24.99, 1, NULL, NULL),
  ('SA-2005-COM', 'WH-GAS-STD',  'Active',    '2019-10-07', NULL,         24.99, 1, NULL, NULL),
  -- Heating protection plans
  ('SA-1001-GAS', 'PP-HEAT',     'Active',    '2018-04-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1003-GAS', 'PP-HEAT',     'Active',    '2017-12-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1005-GAS', 'PP-HEAT',     'Active',    '2016-09-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1007-GAS', 'PP-HEAT',     'Active',    '2019-10-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1009-GAS', 'PP-HEAT',     'Active',    '2018-03-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1010-GAS', 'PP-HEAT',     'Active',    '2015-05-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1012-GAS', 'PP-HEAT',     'Active',    '2017-09-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1014-GAS', 'PP-HEAT',     'Cancelled', '2016-12-01', '2022-11-30', 39.99, 0, '2022-11-30', 'Moved out of service area'),
  ('SA-1016-GAS', 'PP-HEAT',     'Active',    '2019-10-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1020-GAS', 'PP-HEAT',     'Active',    '2015-10-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1022-GAS', 'PP-HEAT',     'Active',    '2021-05-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1024-GAS', 'PP-HEAT',     'Active',    '2020-01-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1028-GAS', 'PP-HEAT',     'Active',    '2018-11-01', NULL,         39.99, 1, NULL, NULL),
  ('SA-1029-GAS', 'PP-HEAT',     'Active',    '2017-06-01', NULL,         39.99, 1, NULL, NULL),
  -- Cooling plans
  ('SA-1003-COOL','PP-COOL',     'Active',    '2019-05-01', NULL,         24.99, 1, NULL, NULL),
  ('SA-1005-GAS', 'PP-COOL',     'Active',    '2016-05-01', NULL,         24.99, 1, NULL, NULL),
  ('SA-1007-COOL','PP-COOL',     'Active',    '2021-06-01', NULL,         24.99, 1, NULL, NULL),
  ('SA-1012-COOL','PP-COOL',     'Active',    '2020-05-01', NULL,         24.99, 1, NULL, NULL),
  ('SA-1015-ELEC','PP-COOL',     'Active',    '2023-02-01', NULL,         24.99, 1, NULL, NULL),
  ('SA-1040-GAS', 'PP-COOL',     'Active',    '2022-07-01', NULL,         24.99, 1, NULL, NULL),
  -- Plumbing protection
  ('SA-1001-GAS', 'PP-PLUMB',    'Active',    '2019-01-01', NULL,         14.99, 1, NULL, NULL),
  ('SA-1005-GAS', 'PP-PLUMB',    'Active',    '2017-01-01', NULL,         14.99, 1, NULL, NULL),
  ('SA-1009-GAS', 'PP-PLUMB',    'Active',    '2020-01-01', NULL,         14.99, 1, NULL, NULL),
  ('SA-1018-GAS', 'PP-PLUMB',    'Cancelled', '2019-01-01', '2023-06-30', 14.99, 0, '2023-06-30', 'Price sensitivity'),
  ('SA-1026-GAS', 'PP-PLUMB',    'Active',    '2016-08-01', NULL,         14.99, 1, NULL, NULL),
  -- Electrical home protection
  ('SA-1001-GAS', 'PP-ELEC-HM',  'Active',    '2022-01-01', NULL,         19.99, 1, NULL, NULL),
  ('SA-1006-GAS', 'PP-ELEC-HM',  'Active',    '2022-01-01', NULL,         19.99, 1, NULL, NULL),
  ('SA-1011-GAS', 'PP-ELEC-HM',  'Active',    '2022-06-01', NULL,         19.99, 1, NULL, NULL),
  ('SA-1032-GAS', 'PP-ELEC-HM',  'Active',    '2022-03-01', NULL,         19.99, 1, NULL, NULL),
  -- Smart home basic
  ('SA-1001-GAS', 'SH-BASIC',    'Active',    '2022-05-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1003-GAS', 'SH-BASIC',    'Active',    '2021-10-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1007-GAS', 'SH-BASIC',    'Active',    '2021-01-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1009-GAS', 'SH-BASIC',    'Active',    '2023-02-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1012-GAS', 'SH-BASIC',    'Active',    '2020-01-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1022-GAS', 'SH-BASIC',    'Active',    '2021-06-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1025-GAS', 'SH-BASIC',    'Active',    '2021-01-01', NULL,         29.99, 1, NULL, NULL),
  ('SA-1030-GAS', 'SH-BASIC',    'Active',    '2022-01-01', NULL,         29.99, 1, NULL, NULL),
  -- Smart home premium
  ('SA-1005-GAS', 'SH-PREM',     'Active',    '2022-06-01', NULL,         59.99, 1, NULL, NULL),
  ('SA-1010-GAS', 'SH-PREM',     'Active',    '2022-09-01', NULL,         59.99, 1, NULL, NULL),
  ('SA-1015-ELEC','SH-PREM',     'Active',    '2023-03-01', NULL,         59.99, 1, NULL, NULL),
  ('SA-1033-GAS', 'SH-PREM',     'Active',    '2022-01-01', NULL,         59.99, 1, NULL, NULL),
  ('SA-1040-GAS', 'SH-PREM',     'Active',    '2022-08-01', NULL,         59.99, 1, NULL, NULL),
  -- ecobee one-time installs
  ('SA-1001-GAS', 'ECOBEE-INST', 'Active',    '2022-04-05', '2022-04-05', 249.00, 0, NULL, NULL),
  ('SA-1003-GAS', 'ECOBEE-INST', 'Active',    '2021-09-12', '2021-09-12', 249.00, 0, NULL, NULL),
  ('SA-1009-GAS', 'ECOBEE-INST', 'Active',    '2023-01-28', '2023-01-28', 249.00, 0, NULL, NULL)
) c(account_number, product_code, contract_status, start_date, end_date, monthly_amount, auto_renew, cancellation_date, cancellation_reason)
JOIN demo.service_accounts sa ON sa.account_number = c.account_number
JOIN demo.products p ON p.product_code = c.product_code;
GO


-- ============================================================
-- SERVICE REQUESTS  (55 rows)
-- ============================================================
INSERT INTO demo.service_requests (service_account_id, equipment_id, request_type, priority, status, description, created_date, scheduled_date, completed_date, technician_id, resolution_notes)
SELECT sa.service_account_id, eq.equipment_id, sr.*
FROM (VALUES
  -- Completed requests (historical)
  ('SA-1001-WH',  'RH2019-041847', 'Maintenance',      'Low',       'Completed', 'Annual flushing and anode rod check',        '2022-11-15 09:00', '2022-11-22', '2022-11-22 14:30', 1012, 'Anode rod 50% depleted, advised replacement within 2 years'),
  ('SA-1005-WH',  'BW2016-088231', 'Emergency Repair', 'Emergency', 'Completed', 'No hot water — pilot light out',             '2023-02-08 07:22', '2023-02-08', '2023-02-08 11:15', 1007, 'Thermocouple replaced, pilot relit, system tested OK'),
  ('SA-1010-GAS', 'LX2015-105522', 'Maintenance',      'Low',       'Completed', 'Annual furnace tune-up',                    '2022-09-20 10:00', '2022-10-05', '2022-10-05 16:00', 1023, 'Filter replaced, heat exchanger inspected, combustion analysis done'),
  ('SA-1003-GAS', 'CR2017-203811', 'Emergency Repair', 'High',      'Completed', 'Furnace not starting — ignitor fault',       '2023-01-12 20:45', '2023-01-13', '2023-01-13 10:30', 1007, 'Hot surface ignitor cracked and replaced'),
  ('SA-1007-COOL','LX2021-AC9920', 'Maintenance',      'Low',       'Completed', 'Spring AC startup check',                   '2023-05-02 08:00', '2023-05-08', '2023-05-08 13:00', 1019, 'Refrigerant level OK, capacitor tested, coils cleaned'),
  ('SA-1012-COOL','GD2020-AC7741', 'Emergency Repair', 'High',      'Completed', 'AC not cooling — refrigerant leak suspect',  '2023-07-15 14:30', '2023-07-15', '2023-07-15 18:00', 1011, 'Refrigerant leak found at service valve, repaired and recharged'),
  ('SA-1009-GAS', 'LX2018-208410', 'Maintenance',      'Low',       'Completed', 'Annual furnace inspection',                 '2022-10-10 09:00', '2022-10-18', '2022-10-18 15:30', 1023, 'System clean, blower motor lubricated, all safeties tested'),
  ('SA-1016-GAS', 'GD2019-394812', 'Maintenance',      'Low',       'Completed', 'Annual furnace tune-up',                    '2023-09-25 11:00', '2023-10-03', '2023-10-03 14:00', 1015, 'Completed standard inspection, new filter installed'),
  ('SA-1005-GAS', 'YK2016-094520', 'Maintenance',      'Low',       'Completed', 'Annual furnace inspection',                 '2023-09-28 10:00', '2023-10-10', '2023-10-10 12:00', 1023, 'All checks pass, heat exchanger clear'),
  ('SA-2001-COM', 'RH2015-COM001', 'Maintenance',      'Medium',    'Completed', 'Quarterly commercial WH service',           '2023-08-01 08:00', '2023-08-07', '2023-08-07 11:30', 1031, 'Sediment flush completed, temperature verified at 60C'),
  ('SA-1001-GAS', 'EB2022-TH3341', 'Installation',     'Low',       'Completed', 'ecobee thermostat install with app setup',  '2022-04-04 09:00', '2022-04-05', '2022-04-05 10:45', 1019, 'ecobee SmartThermostat Premium installed, integrated with furnace and AC'),
  ('SA-1003-GAS', 'EB2021-TH1192', 'Installation',     'Low',       'Completed', 'ecobee enhanced thermostat install',        '2021-09-10 09:00', '2021-09-12', '2021-09-12 11:00', 1019, 'ecobee SmartThermostat Enhanced installed and WiFi configured'),
  ('SA-1015-ELEC','CR2023-HP0041', 'Installation',     'Medium',    'Completed', 'Heat pump install — replacing gas furnace', '2023-01-30 08:00', '2023-02-10', '2023-02-10 17:00', 1008, 'Carrier Infinity 20 installed, old furnace removed, system commissioned'),
  ('SA-1020-GAS', 'LX2015-105522', 'Emergency Repair', 'High',      'Completed', 'Furnace tripping limit switch repeatedly', '2023-12-21 18:00', '2023-12-21', '2023-12-21 21:30', 1007, 'Dirty filter caused overheating, filter replaced, limit reset, all OK'),
  ('SA-1029-GAS', 'YK2017-MUR002', 'Maintenance',      'Low',       'Completed', 'Annual maintenance check',                 '2023-10-05 09:00', '2023-10-12', '2023-10-12 13:30', 1015, 'Inspection completed, minor adjustment to gas pressure'),
  -- In-progress
  ('SA-1018-GAS', NULL,            'Maintenance',      'Low',       'InProgress','Annual gas line inspection',                '2024-04-20 09:00', '2024-04-28', NULL,               1023, NULL),
  ('SA-1033-GAS', NULL,            'Maintenance',      'Low',       'InProgress','Annual furnace tune-up booking',            '2024-04-18 11:00', '2024-04-30', NULL,               1015, NULL),
  ('SA-3001-MUR', 'RH2016-MUR001', 'Maintenance',      'Medium',    'InProgress','Building WH annual service',               '2024-04-22 10:00', '2024-04-25', NULL,               1031, NULL),
  -- Open — backlog
  ('SA-1002-GAS', NULL,            'Maintenance',      'Low',       'Open',      'Customer-requested annual gas safety check','2024-04-28 10:30', NULL,         NULL,               NULL, NULL),
  ('SA-1004-GAS', NULL,            'Maintenance',      'Low',       'Open',      'First annual furnace check (new build)',    '2024-04-25 14:15', NULL,         NULL,               NULL, NULL),
  ('SA-1006-GAS', NULL,            'Inspection',       'Medium',    'Open',      'Gas smell reported — investigate',         '2024-04-30 06:45', NULL,         NULL,               NULL, NULL),
  ('SA-1011-GAS', NULL,            'Emergency Repair', 'High',      'Open',      'No heat — furnace off, house 14C',         '2024-04-29 23:10', NULL,         NULL,               NULL, NULL),
  ('SA-1013-GAS', NULL,            'Maintenance',      'Low',       'Open',      'Protection plan annual furnace service',   '2024-04-27 09:00', NULL,         NULL,               NULL, NULL),
  ('SA-1017-GAS', NULL,            'Inspection',       'Low',       'Open',      'Carbon monoxide detector triggered',       '2024-04-26 20:15', '2024-05-02', NULL,               NULL, NULL),
  ('SA-1019-GAS', NULL,            'Maintenance',      'Low',       'Open',      'Annual furnace check requested by steward','2024-04-23 11:30', NULL,         NULL,               NULL, NULL),
  ('SA-1021-GAS', NULL,            'Emergency Repair', 'Emergency', 'Open',      'Water heater flooding — shut-off needed',  '2024-04-30 15:55', NULL,         NULL,               NULL, NULL),
  ('SA-1023-GAS', NULL,            'Maintenance',      'Low',       'Open',      'Pre-winter furnace inspection',            '2024-04-24 13:00', NULL,         NULL,               NULL, NULL),
  ('SA-1027-GAS', NULL,            'Installation',     'Medium',    'Open',      'New ecobee install — new construction',    '2024-04-29 08:30', '2024-05-03', NULL,               NULL, NULL),
  ('SA-2002-COM', NULL,            'Inspection',       'High',      'Open',      'Smoke detector triggered in HVAC room',    '2024-04-30 11:20', NULL,         NULL,               NULL, NULL),
  ('SA-3005-MUR', 'BW2021-MUR001', 'Emergency Repair', 'High',      'Open',      'WH leaking — multi-unit building floor 3', '2024-04-30 09:40', NULL,         NULL,               NULL, NULL)
) sr(account_number, serial_number, request_type, priority, status, description, created_date, scheduled_date, completed_date, technician_id, resolution_notes)
JOIN demo.service_accounts sa ON sa.account_number = sr.account_number
LEFT JOIN demo.equipment_registry eq ON eq.serial_number = sr.serial_number;
GO


-- ============================================================
-- BILLING TRANSACTIONS  (sample — 200+ rows, 6 months)
-- Generates monthly charges for active contracts + spot payments
-- ============================================================

-- Monthly charges Jan–Jun 2024 for a representative sample of contracts
INSERT INTO demo.billing_transactions (contract_id, service_account_id, transaction_type, transaction_date, due_date, amount, tax_amount, payment_method, status, invoice_number)
SELECT
    c.contract_id,
    c.service_account_id,
    'MonthlyCharge'                                                         AS transaction_type,
    CAST(DATEADD(MONTH, m.n, '2024-01-01') AS DATE)                        AS transaction_date,
    CAST(DATEADD(DAY, 15, DATEADD(MONTH, m.n, '2024-01-01')) AS DATE)      AS due_date,
    c.monthly_amount                                                        AS amount,
    ROUND(c.monthly_amount * 0.13, 2)                                       AS tax_amount,
    CASE (c.contract_id % 3)
        WHEN 0 THEN 'DirectDebit'
        WHEN 1 THEN 'CreditCard'
        ELSE        'Online'
    END                                                                     AS payment_method,
    'Posted'                                                                AS status,
    'INV-' + CAST(2024 AS VARCHAR) + RIGHT('0' + CAST(m.n+1 AS VARCHAR),2)
        + '-' + RIGHT('00000' + CAST(c.contract_id AS VARCHAR), 5)         AS invoice_number
FROM  demo.contracts c
CROSS JOIN (VALUES(0),(1),(2),(3),(4),(5)) m(n)
WHERE c.contract_status = 'Active'
  AND c.billing_frequency = 'Monthly'
  AND c.monthly_amount < 200;   -- excludes one-time ECOBEE installs

-- Corresponding payments (paid within 10 days of posting)
INSERT INTO demo.billing_transactions (contract_id, service_account_id, transaction_type, transaction_date, due_date, amount, tax_amount, payment_method, status, invoice_number)
SELECT
    bt.contract_id,
    bt.service_account_id,
    'Payment'                                                               AS transaction_type,
    CAST(DATEADD(DAY, 10, bt.transaction_date) AS DATE)                    AS transaction_date,
    NULL                                                                    AS due_date,
    -(bt.amount + bt.tax_amount)                                            AS amount,
    0                                                                       AS tax_amount,
    bt.payment_method,
    'Paid'                                                                  AS status,
    bt.invoice_number
FROM demo.billing_transactions bt
WHERE bt.transaction_type = 'MonthlyCharge'
  AND bt.status = 'Posted'
  AND bt.contract_id % 10 != 7;  -- simulate ~10% unpaid for realism

-- One-time ecobee installation charges
INSERT INTO demo.billing_transactions (contract_id, service_account_id, transaction_type, transaction_date, due_date, amount, tax_amount, payment_method, status, invoice_number)
SELECT
    c.contract_id,
    c.service_account_id,
    'OneTimeCharge',
    c.start_date,
    CAST(DATEADD(DAY, 30, c.start_date) AS DATE),
    c.monthly_amount,
    ROUND(c.monthly_amount * 0.13, 2),
    'CreditCard',
    'Posted',
    'INV-OT-' + RIGHT('00000' + CAST(c.contract_id AS VARCHAR), 5)
FROM demo.contracts c
JOIN demo.products p ON p.product_id = c.product_id
WHERE p.billing_frequency = 'OneTime';
GO


-- ============================================================
-- VERIFY LOAD
-- ============================================================
SELECT 'customers'            AS tbl, COUNT(*) AS row_count FROM demo.customers
UNION ALL SELECT 'service_accounts', COUNT(*) FROM demo.service_accounts
UNION ALL SELECT 'products',         COUNT(*) FROM demo.products
UNION ALL SELECT 'contracts',        COUNT(*) FROM demo.contracts
UNION ALL SELECT 'equipment',        COUNT(*) FROM demo.equipment_registry
UNION ALL SELECT 'service_requests', COUNT(*) FROM demo.service_requests
UNION ALL SELECT 'billing',          COUNT(*) FROM demo.billing_transactions
ORDER BY tbl;
GO
