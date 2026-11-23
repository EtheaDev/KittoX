# Maschera di Modifica Testo Email
Maschera di modifica dei [testi e-mail](/emailtemplates) automatiche di [Sport Club Manager](/start).

Sono presenti due dettagli:
- [Testo Email](/emailtemplates_emailtemplate#testo-email)
- [Riceventi](/emailtemplates_emailtemplate#riceventi)

## Testo Email
![Mappa modifica/inserimento](./images/mappatestimail.jpg)

In questa maschera è possibile definire:
### From
Email che invierà la mail automatica.

### Descrizione
Descrizione della mail.

### Oggetto
Oggetto della mail.

### Testo
Testo della mail. Il testo della mail è scritto in formato HTML con l'utilizzo di un comodo editor.

### Uso di "campi variabili" nel Testo
All'interno del testo della mail è possibile anche utilizzare dei **campi variabili** che contengono i **dati** contenuti nell'applicazione. Per utilizzare questi **campi variabili** è possibile definirli tra parentesi graffe: es. {NomeCampo}. Nella tabella sottostante sono elencati tutti i nomi dei **campi** disponibili.

### Uso di "macro speciali" nel Testo
All'interno del testo della mail è possibile anche utilizzare delle **macro speciali** che contengono dei **dati speciali** contenuti nell'applicazione. Per utilizzare questi **campi speciali variabili** è possibile definirli tra caratteri cancelletto: es. #NomeMacro#. Nella tabella sottostante sono elencati tutti i nomi delle **macro speciali** disponibili.

### Uso di "parametri di configurazione" nel Testo
All'interno del testo della mail è possibile anche utilizzare dei **parametri di configurazione** dell'applicazione. Per riferirsi a questi **parametri di configurazione** è necessario utilizzare la sintassi %Config.NomeParametro%. Nella tabella sottostante sono elencati tutti i nomi dei **parametri di configurazione** disponibili.

### Attach
Per gli allegati da inviare.

### Note
Note libere dell'utente.

## Elenco dei campi, macro speciali e parametri di configurazione utilizzabili all'interno dei testi mail
| Codice | Campi | Macro speciale | Parametri di configurazione |
|---|---|---|---|
| REGISTERMAILMESSAGE | Id, TaxCode, Description, LastName, FirstName, Email, Mobile, Password, Profile, Language, Administrator, IsSystem, AccessBlocked, PasswordMustBeChanged, PrivacyConsent, CreationDateTime, IpAddress |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RESETMAILMESSAGE | Password |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| SETPASSWORDMAILMESSAGE |  |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| NOTIFICAVISITAMEDICAMAILMESSAGE | Id, Description, Person, Person_LastName, Person_FirstName, Person_Email, MedicalVisitType, HealthCard, RequestDate, VisitDate, VisitTime, ExpiryDate, Clinic, Clinic_Description, Clinic_Address, ClinicMunicipalityId, ClinicMunicipality, Performed, Notes, Fitness, DocumentFile, OriginalFileName, Status |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RICHIESTAISCRIZIONEMAILMESSAGE | Id, Description, SubscriptionDate, Season, SeasonId, Campaign, CampaignId, Campaign_Description, Campaign_SiblingDiscount, Campaign_SiblingDiscountPercent, Campaign_DiscountDeadline, Campaign_SportsActivityFlag, Campaign_MembershipFee, SubscriptionFee, SubscriptionFeeId, SubscriptionFee_BirthYearFrom, SubscriptionFee_BirthYearTo, SubscriptionFee_SingleInstalmentDiscount, Person, PersonId, LastName, FirstName, TaxCode, Gender, BirthDate, BirthPlace, BirthPlaceId, BirthProvince, BirthProvinceId, BirthCountry, BirthCountryId, Address, Municipality, MunicipalityId, PostalCode, Province, Mobile, Email, VisitExpiry, ParentLastName, ParentTaxCode, ParentMobile, ParentEmail, AcceptanceDate, RejectionDate, SubscriberNotes, ClubNotes, CourseFeeAmount, SiblingDiscount, SiblingDiscountAmount, SingleInstalmentDiscount, SingleInstalmentDiscountAmount, InstalmentsDiscountAllowance, SubscriptionTotal, EntryDateTime, EnteredByUser, EnteredByUserId, IpAddress, Status |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RIFIUTAISCRIZIONEMAILMESSAGE | Id, Description, SubscriptionDate, Season, SeasonId, Campaign, CampaignId, Campaign_Description, Campaign_SiblingDiscount, Campaign_SiblingDiscountPercent, Campaign_DiscountDeadline, Campaign_SportsActivityFlag, Campaign_MembershipFee, SubscriptionFee, SubscriptionFeeId, SubscriptionFee_BirthYearFrom, SubscriptionFee_BirthYearTo, SubscriptionFee_SingleInstalmentDiscount, Person, PersonId, LastName, FirstName, TaxCode, Gender, BirthDate, BirthPlace, BirthPlaceId, BirthProvince, BirthProvinceId, BirthCountry, BirthCountryId, Address, Municipality, MunicipalityId, PostalCode, Province, Mobile, Email, VisitExpiry, ParentLastName, ParentTaxCode, ParentMobile, ParentEmail, AcceptanceDate, RejectionDate, SubscriberNotes, ClubNotes, CourseFeeAmount, SiblingDiscount, SiblingDiscountAmount, SingleInstalmentDiscount, SingleInstalmentDiscountAmount, InstalmentsDiscountAllowance, SubscriptionTotal, EntryDateTime, EnteredByUser, EnteredByUserId, IpAddress, Status |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| APPROVAISCRIZIONEMAILMESSAGE | Id, Description, SubscriptionDate, Season, SeasonId, Campaign, CampaignId, Campaign_Description, Campaign_SiblingDiscount, Campaign_SiblingDiscountPercent, Campaign_DiscountDeadline, Campaign_SportsActivityFlag, Campaign_MembershipFee, SubscriptionFee, SubscriptionFeeId, SubscriptionFee_BirthYearFrom, SubscriptionFee_BirthYearTo, SubscriptionFee_SingleInstalmentDiscount, Person, PersonId, LastName, FirstName, TaxCode, Gender, BirthDate, BirthPlace, BirthPlaceId, BirthProvince, BirthProvinceId, BirthCountry, BirthCountryId, Address, Municipality, MunicipalityId, PostalCode, Province, Mobile, Email, VisitExpiry, ParentLastName, ParentTaxCode, ParentMobile, ParentEmail, AcceptanceDate, RejectionDate, SubscriberNotes, ClubNotes, CourseFeeAmount, SiblingDiscount, SiblingDiscountAmount, SingleInstalmentDiscount, SingleInstalmentDiscountAmount, InstalmentsDiscountAllowance, SubscriptionTotal, EntryDateTime, EnteredByUser, EnteredByUserId, IpAddress, Status, RataIscrizione:1:Amount, RataIscrizione:1:TotalAmount, RataIscrizione:1:DueDate, RataIscrizione:2:Amount, RataIscrizione:2:TotalAmount, RataIscrizione:2:DueDate | IstruzioniIscrizione | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RICHIESTAPAGAMENTOMAILMESSAGE | Id, Description, Payment, SubscriptionInstalment, SubscriptionInstalment_SubscriptionId, SubscriptionInstalment_DueDate, InstalmentAmount, InstalmentPaidAmount, InstalmentOutstandingAmount, PaidAmount, MasterRecord.Id, MasterRecord.Description, MasterRecord.Payer, MasterRecord.Payer_LastName, MasterRecord.Payer_FirstName, MasterRecord.Payer_Email, MasterRecord.PaymentMethod, MasterRecord.PaymentMethod_RequiresBankDetails, MasterRecord.PaymentDate, MasterRecord.DepositBank, MasterRecord.ChequeBank, MasterRecord.ChequeNumber, MasterRecord.TransferReference, MasterRecord.Amount, MasterRecord.PostingDate, MasterRecord.ValueDate, MasterRecord.LinesTotalAmount, MasterRecord.Status, MasterRecord.ApprovalDate, MasterRecord.RejectionDate |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RIFIUTOPAGAMENTOMAILMESSAGE | Id, Description, Payment, SubscriptionInstalment, SubscriptionInstalment_SubscriptionId, SubscriptionInstalment_DueDate, InstalmentAmount, InstalmentPaidAmount, InstalmentOutstandingAmount, PaidAmount, MasterRecord.Id, MasterRecord.Description, MasterRecord.Payer, MasterRecord.Payer_LastName, MasterRecord.Payer_FirstName, MasterRecord.Payer_Email, MasterRecord.PaymentMethod, MasterRecord.PaymentMethod_RequiresBankDetails, MasterRecord.PaymentDate, MasterRecord.DepositBank, MasterRecord.ChequeBank, MasterRecord.ChequeNumber, MasterRecord.TransferReference, MasterRecord.Amount, MasterRecord.PostingDate, MasterRecord.ValueDate, MasterRecord.LinesTotalAmount, MasterRecord.Status, MasterRecord.ApprovalDate, MasterRecord.RejectionDate |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| CONFERMAPAGAMENTOMAILMESSAGE | Id, Description, Payment, SubscriptionInstalment, SubscriptionInstalment_SubscriptionId, SubscriptionInstalment_DueDate, InstalmentAmount, InstalmentPaidAmount, InstalmentOutstandingAmount, PaidAmount, MasterRecord.Id, MasterRecord.Description, MasterRecord.Payer, MasterRecord.Payer_LastName, MasterRecord.Payer_FirstName, MasterRecord.Payer_Email, MasterRecord.PaymentMethod, MasterRecord.PaymentMethod_RequiresBankDetails, MasterRecord.PaymentDate, MasterRecord.DepositBank, MasterRecord.ChequeBank, MasterRecord.ChequeNumber, MasterRecord.TransferReference, MasterRecord.Amount, MasterRecord.PostingDate, MasterRecord.ValueDate, MasterRecord.LinesTotalAmount, MasterRecord.Status, MasterRecord.ApprovalDate, MasterRecord.RejectionDate |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |
| RICEVUTADISPONIBILEMAILMESSAGE | Id, Description, LastName, FirstName, TaxCode, Address, PostalCode, Municipality, ProvinceId, Province, DeductionPercent, SubscriberLastName, SubscriberFirstName, SubscriberBirthDate, SubscriberBirthMunicipality, SubscriberBirthProvinceId, SubscriberBirthProvince, SubscriberTaxCode, PaidAmount, AmountPercent, Number, Year, PrintDate, DocumentFile, OriginalFileName, PaymentMethod, CampaignDescription, PresidentLastName, PresidentFirstName, Person, PaymentDate |  | AppTitle, HomeUrl, SportsClubName, SportsClubEmail, SupportEmail |

## Riceventi

![Mappa modifica/inserimento](./images/mappatestimailriceventi.jpg)

In questa maschera è possibile definire:
### CC Indirizzi
Gli indirizzi mail a cui inviare la mail per conoscenza.

### BCC Indirizzi
Gli indirizzi mail a cui inviare la mail per conoscenza nascosta.

### Indirizzi da escludere
Indirizzi a cui non inviare la mail.
