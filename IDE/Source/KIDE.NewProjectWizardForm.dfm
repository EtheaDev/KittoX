inherited NewProjectWizardForm: TNewProjectWizardForm
  HelpContext = 120
  BorderStyle = bsDialog
  Caption = 'New KittoX Application'
  ClientHeight = 357
  ClientWidth = 562
  StyleElements = [seFont, seClient, seBorder]
  OnCreate = FormCreate
  ExplicitWidth = 578
  ExplicitHeight = 396
  TextHeight = 13
  inherited PageControl: TPageControl
    Width = 562
    Height = 296
    ActivePage = SelectTabSheet
    ExplicitWidth = 562
    ExplicitHeight = 296
    object SelectTabSheet: TTabSheet
      Caption = 'SelectTabSheet'
      object TemplateSplitter: TSplitter
        Left = 270
        Top = 0
        Height = 265
        Align = alRight
        AutoSnap = False
        MinSize = 50
        ExplicitLeft = 392
        ExplicitTop = 56
        ExplicitHeight = 100
      end
      inline TemplateFrame: TProjectTemplateFrame
        Left = 0
        Top = 0
        Width = 270
        Height = 265
        Align = alClient
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        ExplicitWidth = 270
        ExplicitHeight = 265
        inherited ListView: TListView
          Width = 270
          Height = 265
          ExplicitWidth = 270
          ExplicitHeight = 265
        end
      end
      object TemplateInfoPanel: TPanel
        Left = 273
        Top = 0
        Width = 281
        Height = 265
        Align = alRight
        BevelOuter = bvNone
        TabOrder = 1
        object TemplateInfoRichEdit: TRichEdit
          Left = 0
          Top = 0
          Width = 281
          Height = 265
          Align = alClient
          Color = clBtnFace
          Font.Charset = ANSI_CHARSET
          Font.Color = clWindowText
          Font.Height = -11
          Font.Name = 'Courier New'
          Font.Style = []
          ParentFont = False
          ReadOnly = True
          ScrollBars = ssVertical
          TabOrder = 0
        end
      end
    end
    object OptionsTabSheet: TTabSheet
      Caption = 'OptionsTabSheet'
      ImageIndex = 1
      object AuthenticationtypeLabel: TLabel
        Left = 25
        Top = 85
        Width = 95
        Height = 13
        Caption = 'Authentication type'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
      end
      object AccessControltypeLabel: TLabel
        Left = 25
        Top = 131
        Width = 96
        Height = 13
        Caption = 'Access Control type'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = []
        ParentFont = False
      end
      object ExtJSLabel: TLabel
        Left = 398
        Top = 3
        Width = 32
        Height = 13
        Caption = 'HTMX'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object ThemeLabel: TLabel
        Left = 405
        Top = 20
        Width = 32
        Height = 13
        Alignment = taRightJustify
        Caption = 'Theme'
      end
      object LanguagEEncodingLabel: TLabel
        Left = 210
        Top = 3
        Width = 120
        Height = 13
        Caption = 'Language && Encoding'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object LanguageLabel: TLabel
        Left = 223
        Top = 20
        Width = 47
        Height = 13
        Alignment = taRightJustify
        Caption = 'Language'
      end
      object CharsetLabel: TLabel
        Left = 223
        Top = 66
        Width = 38
        Height = 13
        Alignment = taRightJustify
        Caption = 'Charset'
      end
      object PortLabel: TLabel
        Left = 223
        Top = 128
        Width = 20
        Height = 13
        Alignment = taRightJustify
        Caption = 'Port'
      end
      object ServerLabel: TLabel
        Left = 210
        Top = 109
        Width = 38
        Height = 13
        Caption = 'Server'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object ThreadPoolSizeLabel: TLabel
        Left = 223
        Top = 175
        Width = 73
        Height = 13
        Alignment = taRightJustify
        Caption = 'ThreadPoolSize'
      end
      object SessionTimeOutLabel: TLabel
        Left = 223
        Top = 222
        Width = 76
        Height = 13
        Alignment = taRightJustify
        Caption = 'SessionTimeOut'
      end
      object FeaturesLabel: TLabel
        Left = 10
        Top = 66
        Width = 50
        Height = 13
        Caption = 'Features'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object ProjectOptionsLabel: TLabel
        Left = 10
        Top = 1
        Width = 86
        Height = 13
        Caption = 'Project options'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Tahoma'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object SearchPathLabel: TLabel
        Left = 20
        Top = 20
        Width = 83
        Height = 13
        Caption = 'Kitto Search Path'
      end
      object AuthComboBox: TComboBox
        Left = 25
        Top = 104
        Width = 156
        Height = 21
        TabOrder = 1
      end
      object ACComboBox: TComboBox
        Left = 25
        Top = 150
        Width = 156
        Height = 21
        TabOrder = 2
      end
      object ExtThemeComboBox: TComboBox
        Left = 405
        Top = 39
        Width = 79
        Height = 21
        TabOrder = 9
        Text = 'Auto'
        Items.Strings = (
          'Auto'
          'Dark'
          'Light')
      end
      object LanguageIdComboBox: TComboBox
        Left = 223
        Top = 39
        Width = 82
        Height = 21
        ItemIndex = 0
        TabOrder = 4
        Text = 'en'
        Items.Strings = (
          'en'
          'it')
      end
      object CharsetComboBox: TComboBox
        Left = 223
        Top = 82
        Width = 82
        Height = 21
        ItemIndex = 0
        TabOrder = 5
        Text = 'utf-8'
        Items.Strings = (
          'utf-8'
          'iso-8859-1')
      end
      object ServerPortEdit: TSpinEdit
        Left = 223
        Top = 147
        Width = 79
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 6
        Value = 8080
      end
      object DatabasesGroupBox: TGroupBox
        Left = 25
        Top = 175
        Width = 156
        Height = 89
        Caption = 'Database Adapters'
        TabOrder = 3
        object DBADOCheckBox: TCheckBox
          Left = 7
          Top = 17
          Width = 97
          Height = 17
          Caption = 'ADO'
          TabOrder = 0
        end
        object DBDBXCheckBox: TCheckBox
          Left = 7
          Top = 38
          Width = 97
          Height = 17
          Caption = 'DBExpress'
          TabOrder = 1
        end
        object DBFDCheckBox: TCheckBox
          Left = 7
          Top = 59
          Width = 97
          Height = 17
          Caption = 'FireDac'
          TabOrder = 2
        end
      end
      object ServerThreadPoolSizeEdit: TSpinEdit
        Left = 223
        Top = 194
        Width = 79
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 7
        Value = 20
      end
      object ServerSessionTimeOutEdit: TSpinEdit
        Left = 223
        Top = 241
        Width = 79
        Height = 22
        MaxValue = 0
        MinValue = 0
        TabOrder = 8
        Value = 10
      end
      object SearchPathComboBox: TComboBox
        Left = 20
        Top = 39
        Width = 161
        Height = 21
        Hint = 'Root Kitto directory as seen by the Delphi project'
        TabOrder = 0
      end
    end
    object GoTabSheet: TTabSheet
      Caption = 'GoTabSheet'
      ImageIndex = 2
      DesignSize = (
        554
        265)
      object ProjectPathButton: TSpeedButton
        Left = 517
        Top = 32
        Width = 23
        Height = 22
        Hint = 'Select an empty directory for the new project'
        Anchors = [akTop, akRight]
        Caption = '...'
        OnClick = ProjectPathButtonClick
        ExplicitLeft = 653
      end
      object ProjectPathEdit: TLabeledEdit
        Left = 24
        Top = 32
        Width = 487
        Height = 21
        Anchors = [akLeft, akTop, akRight]
        EditLabel.Width = 105
        EditLabel.Height = 13
        EditLabel.Caption = 'New Project Directory'
        TabOrder = 0
        Text = ''
      end
      object ProjectNameEdit: TLabeledEdit
        Left = 24
        Top = 80
        Width = 137
        Height = 21
        EditLabel.Width = 64
        EditLabel.Height = 13
        EditLabel.Caption = 'Project Name'
        TabOrder = 1
        Text = ''
        OnChange = ProjectNameEditChange
      end
      object AppTitleEdit: TLabeledEdit
        Left = 167
        Top = 80
        Width = 344
        Height = 21
        EditLabel.Width = 75
        EditLabel.Height = 13
        EditLabel.Caption = 'Application Title'
        TabOrder = 2
        Text = ''
      end
    end
    object DoneTabSheet: TTabSheet
      Caption = 'DoneTabSheet'
      ImageIndex = 3
      object ProjectCreatedRichEdit: TRichEdit
        Left = 0
        Top = 0
        Width = 554
        Height = 265
        Align = alClient
        Color = clBtnFace
        Font.Charset = ANSI_CHARSET
        Font.Color = clWindowText
        Font.Height = -11
        Font.Name = 'Courier New'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
  end
  inherited ButtonPanel: TPanel
    Top = 321
    Width = 562
    StyleElements = [seFont, seClient, seBorder]
    ExplicitTop = 321
    ExplicitWidth = 562
    inherited BackButton: TButton
      Left = 402
      ExplicitLeft = 402
    end
    inherited ForwardButton: TButton
      Left = 483
      ExplicitLeft = 483
    end
  end
  inherited TitlePanel: TPanel
    Width = 552
    StyleElements = [seFont, seClient, seBorder]
    ExplicitWidth = 552
  end
  inherited ActionList: TActionList
    Left = 496
  end
end
