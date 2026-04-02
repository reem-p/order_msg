CREATE TABLE dbo.Message_Types (
    msg_type INT PRIMARY KEY,
    msg_name NVARCHAR(100),
    msg_template NVARCHAR(MAX),
    is_active BIT DEFAULT 1,
    created_at DATETIME DEFAULT GETDATE()
);

INSERT INTO dbo.Message_Types (msg_type, msg_name, msg_template)
VALUES
(1, N'ÿ·» ”œ«œ - „ﬁ«Ì”…', N'—Ã«¡ ”œ«œ „ﬁ«Ì”… ﬂÂ—»«¡ ⁄œ«œ »‹ﬁÌ„… {msg_amt} ÿ·» —ﬁ„ {oh_no} »«”„/{oh_name}° ‘„«· «·ﬁ«Â—…'),
(2, N'‘ﬂ—« ·”œ«œ - „ﬁ«Ì”…', N'‰‘ﬂ—ﬂ„ ⁄·Ï ”œ«œ „ﬁ«Ì”… ﬂÂ—»«¡ ⁄œ«œ »‹ﬁÌ„… {msg_amt} ÿ·» —ﬁ„ {oh_no} »«”„/{oh_name}° ‘„«· «·ﬁ«Â—…'),
(3, N'ÿ·» ”œ«œ - ﬁ”ÿ', N'—Ã«¡ ”œ«œ ﬁ”ÿ  —ﬂÌ» ⁄œ«œ ﬂÂ—»«¡ »‹ﬁÌ„… {msg_amt} ÿ·» —ﬁ„ {oh_no} »«”„/{oh_name}° ‘„«· «·ﬁ«Â—…'),
(4, N'‘ﬂ—« ·”œ«œ - ﬁ”ÿ', N'‰‘ﬂ—ﬂ„ ⁄·Ï ”œ«œ ﬁ”ÿ  —ﬂÌ» ⁄œ«œ ﬂÂ—»«¡ »‹ﬁÌ„… {msg_amt} ÿ·» —ﬁ„ {oh_no} »«”„/{oh_name}° ‘„«· «·ﬁ«Â—…');