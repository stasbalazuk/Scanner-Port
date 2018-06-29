object Form1: TForm1
  Left = 632
  Top = 345
  Width = 561
  Height = 267
  Caption = 'ScanPort'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 8
    Top = 200
    Width = 113
    Height = 25
    Caption = #1057#1082#1072#1085#1080#1088#1086#1074#1072#1090#1100' '#1087#1086#1088#1090#1099
    TabOrder = 0
    OnClick = Button1Click
  end
  object ProgressBar1: TProgressBar
    Left = 8
    Top = 176
    Width = 537
    Height = 17
    Max = 7000
    TabOrder = 1
  end
  object GroupBox1: TGroupBox
    Left = 8
    Top = 8
    Width = 185
    Height = 49
    Caption = ' IP '
    TabOrder = 2
    object AddressEdit: TEdit
      Left = 8
      Top = 18
      Width = 169
      Height = 21
      TabOrder = 0
    end
  end
  object GroupBox2: TGroupBox
    Left = 8
    Top = 64
    Width = 185
    Height = 49
    Caption = ' '#1053#1072#1095#1072#1083#1100#1085#1099#1081' '#1087#1086#1088#1090' '
    TabOrder = 3
    object StartPortEdit: TEdit
      Left = 8
      Top = 18
      Width = 169
      Height = 21
      TabOrder = 0
      Text = '1'
    end
  end
  object GroupBox3: TGroupBox
    Left = 8
    Top = 120
    Width = 185
    Height = 49
    Caption = ' '#1050#1086#1085#1077#1095#1085#1099#1081' '#1087#1086#1088#1090' '
    TabOrder = 4
    object EndPortEdit: TEdit
      Left = 8
      Top = 18
      Width = 169
      Height = 21
      TabOrder = 0
      Text = '65535'
    end
  end
  object GroupBox4: TGroupBox
    Left = 200
    Top = 8
    Width = 345
    Height = 161
    Caption = ' Log '
    TabOrder = 5
    object DisplayMemo: TRichEdit
      Left = 8
      Top = 16
      Width = 329
      Height = 137
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
end
