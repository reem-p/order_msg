CREATE TABLE dbo.Message_ProcessStatus (
    status_id INT PRIMARY KEY,
    status_name NVARCHAR(50)
);

INSERT INTO dbo.Message_ProcessStatus (status_id, status_name)
VALUES
(0, N'Ã«Â“'),
(1, N' „ «· ‰›Ì–'),
(2, N'ﬁÌœ «· ‰›Ì–'),
(3, N'›‘· „ƒﬁ '),
(4, N'„—›Ê÷ ‰Â«∆Ì«');