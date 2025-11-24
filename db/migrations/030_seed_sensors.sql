-- Seed initial sensors

INSERT INTO sensors (type, location)
VALUES
    ('frog-detector','AUVIC_Yirraba_11F'),
    ('frog-detector','AUVIC_Yirraba_12A'),
    ('frog-detector','FAKE_LOCATION_X'),
    ('other-detector','FAKE_LOCATION_Y')
ON CONFLICT (type, location) DO NOTHING;
