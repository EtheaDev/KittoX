-- HelloKitto PostgreSQL Data Script
-- Generated: 2026-04-27 (refreshed from live MSSQL HelloKitto database)
-- Schema: hellokitto. Identifiers in lowercase to match the DDL.
-- Boolean columns (kitto_users.is_active/.must_change_password,
-- invitation.accepted) use TRUE/FALSE literals.
-- Picture blob data is NOT included; pictures can be uploaded via the app.
--
-- Usage: psql -d <database> -f HelloKitto_PostgreSQL_Data.sql

-- kitto_users
INSERT INTO hellokitto.kitto_users (user_name, password_hash, email_address, must_change_password, is_active) VALUES ('administrator', 'baae429e0afb2aa9dac0a665abefdd8a', NULL, FALSE, TRUE);
INSERT INTO hellokitto.kitto_users (user_name, password_hash, email_address, must_change_password, is_active) VALUES ('guest', 'password', 'email@domain.com', FALSE, TRUE);

-- hair
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('1', 'Blond');
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('2', 'Walnut');
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('3', 'Black');
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('4', 'Silver');
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('5', 'Red');
INSERT INTO hellokitto.hair (hair_id, hair_color) VALUES ('6', 'Platinum');

-- girl
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('A', 'CHERRY', 13, '5', ' 39021-3349695');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('B', 'LOUISE', 15, '4', '+39011-9387495');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('C', 'AMANDA', 14, '3', '+440331-66782176');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('D', 'SHIRLEY', 11, '5', '+42032-7652435');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('E', 'DEBBIE', 16, '2', '+3902-487364281');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('F', 'JENNIFER', 10, '1', '+39033-64538404');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('300E51B4BBB6EF4AA485551E5993D84F', 'JUDY', 11, '3', '234234234');
INSERT INTO hellokitto.girl (girl_id, girl_name, age, hair_id, phone) VALUES ('FD5B538E93098142956A649AA0A45F8A', 'JESSICA', 12, '3', '123235345');

-- doll
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('0193347', 'SAMANTHA', '2000-01-01', '5', 'S', 'E', 'Dirty');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('2213', 'ANDREA', '2023-12-31', '5', 'L', 'A', 'Angryàèiòù');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('3325', 'BILLIE', '2000-01-01', '3', 'M', 'A', 'Messy');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('47568', 'BONNIE', '2023-02-01', '3', 'S', 'B', 'Smiling');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('7222ECD31ACD0743A656FF7081124409', 'PEGGY', '2026-04-08', '2', 'S', 'A', 'Beatiful Girl with accessories');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('7676', 'DONNA', '2011-05-23', '2', 'XL', 'D', 'Shiny');
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('8895C4DE9216A243BB39A3B50970F02D', 'SIDNEY', '2020-02-12', '1', 'S', 'C', NULL);
INSERT INTO hellokitto.doll (doll_id, doll_name, date_bought, hair_id, dress_size, mom_id, aspect) VALUES ('985400', 'BRENDA', '2027-01-01', '1', 'M', 'D', 'Curly');

-- party
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('ybyay', 'Halloween Party', '2021-10-31', '16:45:00', 'Paseo de Gracia, 101 - Barcelona');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('oius', 'Pinata Party', '2021-11-09', '20:00:00', 'Rue de Lausanne, 11 - Zurich');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('vndjs', 'Beach Party', '2021-11-13', '15:00:00', 'Wuthering Heights, 65 - Los Angeles');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('chdfhd', 'Splish Splash', '2021-12-02', '17:30:00', 'Via col Vento, 20 - Verona');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2022a', 'Carnival Dress Up', '2022-02-26', '20:00:00', 'Rainbow Boulevard, 12 - Candyland');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2022b', 'Summer Ice Cream', '2022-07-16', '18:00:00', 'Sunshine Beach, 5 - Miami');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2022c', 'Pumpkin Painting', '2022-10-01', '15:00:00', 'Maple Lane, 8 - Boston');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2023a', 'Confetti Countdown', '2023-01-01', '00:30:00', 'Starlight Avenue, 1 - Paris');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2023b', 'Butterfly Garden', '2023-04-15', '15:00:00', 'Daisy Meadow, 3 - London');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2023c', 'Fairy Dance', '2023-06-24', '21:00:00', 'Moonlight Park, 7 - Stockholm');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2023d', 'Gingerbread House', '2023-12-23', '15:00:00', 'Snowflake Street, 12 - Vienna');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2024a', 'Friendship Bracelets', '2024-02-14', '15:00:00', 'Heartland Plaza, 33 - Roma');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2024b', 'Bubble Blowing', '2024-06-08', '16:00:00', 'Cloud Garden, 10 - Singapore');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2024c', 'Treasure Hunt', '2024-09-21', '14:00:00', 'Golden Fields, 20 - California');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2024d', 'Glitter Ball', '2024-12-31', '18:00:00', 'Sparkle Square, 1 - New York');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2025a', 'Snowflake Tea Party', '2025-01-18', '15:00:00', 'Icicle Chalet, 5 - Chamonix');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2025b', 'Blossom Picnic', '2025-03-29', '11:00:00', 'Sakura Park, 3 - Tokyo');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2025c', 'Sandcastle Contest', '2025-08-15', '14:00:00', 'Seashell Bay, 100 - Rio');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2025d', 'Pajama Sleepover', '2025-11-27', '17:00:00', 'Cozy Lane, 50 - New York');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2026a', 'Tiara Brunch', '2026-01-06', '11:00:00', 'Princess Corso, 22 - Milano');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('417A57AE51386F48A0AE52CFEE0E90D2', 'test KittoX', '2026-04-02', '10:10:00', 'Rue de la muerte');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2026b', 'Egg Hunt Adventure', '2026-04-05', '10:00:00', 'Bunny Meadow, 1 - London');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2026c', 'Sparkler Parade', '2026-07-04', '18:00:00', 'Fireworks Mall, 1 - Washington DC');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2026d', 'Pony Ride Picnic', '2026-10-10', '14:30:00', 'Sunflower Hills, 15 - Toscana');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('p2026e', 'Cookie Decorating', '2026-12-20', '15:00:00', 'Candy Cane Platz, 3 - Berlin');
INSERT INTO hellokitto.party (party_id, party_name, party_date, party_time, address) VALUES ('aswdeo', 'Pool Party', '2027-12-10', '19:35:00', 'Raspberry Circle, 2 - Manchester');

-- invitation
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('47BB934A7DFF0A4EAB8FC3361BC460AA', '417A57AE51386F48A0AE52CFEE0E90D2', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('66B3385A467E4645AD895E0EC501BE24', '417A57AE51386F48A0AE52CFEE0E90D2', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('8C1F4A548585DD45A692FE1BA8AD6B28', 'aswdeo', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('C85B63A5D2EAFB499874BB7599096FC6', 'aswdeo', 'A', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('D9623F742C876D4DB2E5A736F0A28FA1', 'aswdeo', '300E51B4BBB6EF4AA485551E5993D84F', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('E49514A98AC99E49AB460F96E6649A07', 'aswdeo', 'E', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('159366E5475BEF45B2A79B0582E40FB0', 'chdfhd', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('FBB2139ECCA47347AB6FA1CA54B16479', 'chdfhd', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('04E63319002E824FA88F253F8F5A047D', 'oius', 'B', NULL);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('0A0AFA46F5A9444882FEB3E0A5141315', 'oius', 'F', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('8D128E7BD85DDE4DA3AA346BB31B3446', 'oius', 'D', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('B1FFE34266785740B0103CB0905F09E0', 'oius', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv14', 'p2022a', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv15', 'p2022a', 'F', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv16', 'p2023a', 'B', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv17', 'p2023a', 'D', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv18', 'p2023a', 'E', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv19', 'p2024a', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv20', 'p2024a', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv21', 'p2025b', 'FD5B538E93098142956A649AA0A45F8A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv22', 'p2025b', '300E51B4BBB6EF4AA485551E5993D84F', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv23', 'p2025b', 'F', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv01', 'p2026b', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv02', 'p2026b', 'B', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv03', 'p2026b', 'C', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv04', 'p2026c', 'D', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv05', 'p2026c', 'E', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv06', 'p2026c', 'F', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv07', 'p2026d', 'A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv08', 'p2026d', 'FD5B538E93098142956A649AA0A45F8A', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv09', 'p2026d', '300E51B4BBB6EF4AA485551E5993D84F', FALSE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv10', 'p2026e', 'B', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv11', 'p2026e', 'C', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv12', 'p2026e', 'D', TRUE);
INSERT INTO hellokitto.invitation (invitation_id, party_id, invitee_id, accepted) VALUES ('inv13', 'p2026e', 'E', FALSE);
