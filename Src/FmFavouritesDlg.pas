{
 * This Source Code Form is subject to the terms of the Mozilla Public License,
 * v. 2.0. If a copy of the MPL was not distributed with this file, You can
 * obtain one at http://mozilla.org/MPL/2.0/
 *
 * Copyright (C) 2013, Peter Johnson (www.delphidabbler.com).
 *
 * $Rev$
 * $Date$
 *
 * Implements a dialogue box that displays and manages the user's favourite
 * snippets.
}


unit FmFavouritesDlg;


interface


uses
  // Delphi
  Classes, ActnList, StdCtrls, Controls, ExtCtrls, Forms, ComCtrls, Types,
  Generics.Collections {must be listed after Classes},
  // 3rd party
  LVEx,
  // Project
  USnippetIDs,
  FmGenericNonModalDlg, Favourites.UFavourites, IntfNotifier, UWindowSettings;


type
  TFavouritesDlg = class(TGenericNonModalDlg)
    alDlg: TActionList;
    btnDisplay: TButton;
    btnDelete: TButton;
    btnDeleteAll: TButton;
    actDelete: TAction;
    actDeleteAll: TAction;
    actDisplay: TAction;
    chkNewTab: TCheckBox;
    tbTransparency: TTrackBar;
    lblTransparency: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure actDisplayUpdate(Sender: TObject);
    procedure actDisplayExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure actDeleteUpdate(Sender: TObject);
    procedure actDeleteExecute(Sender: TObject);
    procedure actDeleteAllUpdate(Sender: TObject);
    procedure actDeleteAllExecute(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure tbTransparencyChange(Sender: TObject);
    procedure tbTransparencyKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure tbTransparencyKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  strict private
    type
      TPersistentOptions = class(TObject)
      strict private
        var
          fDisplayInNewTabs: Boolean;
          fInactiveAlphaBlendValue: Byte;
      public
        constructor Create;
        destructor Destroy; override;
        property DisplayInNewTabs: Boolean
          read fDisplayInNewTabs write fDisplayInNewTabs;
        property InactiveAlphaBlendValue: Byte
          read fInactiveAlphaBlendValue write fInactiveAlphaBlendValue;
      end;
  strict private
    var
      fLVFavs: TListViewEx;
      fFavourites: TFavourites;
      fNotifier: INotifier;
      fOptions: TPersistentOptions;
      fWindowSettings: TDlgWindowSettings;
      fTrackBarKeyDown: Boolean;
      fTrackBarMouseDown: Boolean;
    class var
      fInstance: TFavouritesDlg;
    ///  <summary>Specifies that a TFavouriteListItem is to be used to create
    ///  new list view items.</summary>
    procedure LVFavouriteCreateItemClass(Sender: TCustomListView;
      var ItemClass: TListItemClass);
    ///  <summary>Compares two list items, Item1 and Item2, using text contained
    ///  in row specified Data parameter, recording result of comparison in
    ///  Compare parameter.</summary>
    procedure LVFavouritesCompare(Sender: TObject; Item1, Item2: TListItem;
      Data: Integer; var Compare: Integer);
    procedure LVDoubleClick(Sender: TObject);
    procedure LVCustomDrawItem(Sender: TCustomListView; Item: TListItem;
      State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure LVCustomDrawSubItem(Sender: TCustomListView; Item: TListItem;
      SubItem: Integer; State: TCustomDrawState; var DefaultDraw: Boolean);
    ///  <summary>Returns text of list item LI in column specified by Idx.
    ///  </summary>
    ///  <remarks>Idx = 0 returns list item's caption while Idx > 0 returns text
    ///  of SubItem[Idx-1].</remarks>
    procedure CreateLV;
    procedure PopulateLV;
    procedure ReSortLV;
    procedure AddLVItem(const Favourite: TFavourite);
    procedure RemoveLVItem(const Favourite: TFavourite);
    procedure FavouritesListener(Sender: TObject; const EvtInfo: IInterface);
    procedure FadeTo(const EndTransparency: Byte);
    procedure FadeIn;
    procedure FadeOut;
    function FindListItem(const SnippetID: TSnippetID): TListItem;
    procedure TBTransparencyMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure TBTransparencyMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  strict protected
    procedure ConfigForm; override;
    procedure ArrangeForm; override;
    procedure InitForm; override;
  public
    class procedure Display(AOwner: TComponent; const Favourites: TFavourites;
      Notifier: INotifier);
    class procedure Close;
    class function IsDisplayed: Boolean;
  end;


implementation


uses
  // Delphi
  SysUtils, DateUtils, Windows, Graphics,
  // Project
  UCtrlArranger, UMessageBox, UPreferences, USettings, UStructs, UStrUtils;

{$R *.dfm}


type
  ///  <summary>Custom list item class that adds ability to store a TFavourite
  ///  record with list item.</summary>
  TFavouriteListItem = class(TListItem)
  strict private
    var
      ///  <summary>Value of Warning property.</summary>
      fFavourite: TFavourite;
  public
    ///  <summary>Favourite associated with list item.</summary>
    property Favourite: TFavourite read fFavourite write fFavourite;
  end;

type
  ///  <summary>Hack to enable OnMouseUp and OnMouseDown events of TTrackBar to
  ///  be set.</summary>
  ///  <remarks>For some reason these events are protected in TTrackBar.
  ///  </remarks>
  TTrackBarHack = class(TTrackBar);

{ TFavouritesDlg }

procedure TFavouritesDlg.actDeleteAllExecute(Sender: TObject);
resourcestring
  sQuery = 'Do you really want to delete all your favourites?';
begin
  if TMessageBox.Confirm(Self, sQuery) then
  begin
    fLVFavs.Items.BeginUpdate;
    try
      fFavourites.Clear;
    finally
      fLVFavs.Items.EndUpdate;
    end;
  end;
end;

procedure TFavouritesDlg.actDeleteAllUpdate(Sender: TObject);
begin
  actDeleteAll.Enabled := not fFavourites.IsEmpty;
end;

procedure TFavouritesDlg.actDeleteExecute(Sender: TObject);
var
  LI: TFavouriteListItem;
begin
  LI := fLVFavs.Selected as TFavouriteListItem;
  fFavourites.Remove(LI.Favourite.SnippetID);
end;

procedure TFavouritesDlg.actDeleteUpdate(Sender: TObject);
begin
  actDelete.Enabled := Assigned(fLVFavs.Selected);
end;

procedure TFavouritesDlg.actDisplayExecute(Sender: TObject);
var
  LI: TFavouriteListItem;
  SelectedSnippet: TSnippetID;
begin
  LI := fLVFavs.Selected as TFavouriteListItem;
  SelectedSnippet := LI.Favourite.SnippetID;
  fNotifier.DisplaySnippet(
    SelectedSnippet.Name,
    SelectedSnippet.UserDefined,
    chkNewTab.Checked
  );
  fFavourites.Touch(SelectedSnippet);
  fLVFavs.Selected := FindListItem(SelectedSnippet);
end;

procedure TFavouritesDlg.actDisplayUpdate(Sender: TObject);
begin
  actDisplay.Enabled := Assigned(fLVFavs.Selected);
end;

procedure TFavouritesDlg.AddLVItem(const Favourite: TFavourite);
var
  LI: TFavouriteListItem;
begin
  LI := fLVFavs.Items.Add as TFavouriteListItem;
  LI.Caption := Favourite.SnippetID.Name;
  if IsToday(Favourite.LastAccessed) then
    LI.SubItems.Add(TimeToStr(Favourite.LastAccessed))
  else
    LI.SubItems.Add(DateTimeToStr(Favourite.LastAccessed));
  LI.Favourite := Favourite;
end;

procedure TFavouritesDlg.ArrangeForm;
begin
  TCtrlArranger.AlignTops([fLVFavs, btnDisplay], 0);
  TCtrlArranger.AlignLefts([fLVFavs, chkNewTab], 0);
  TCtrlArranger.AlignLefts(
    [btnDisplay, btnDelete, btnDeleteAll],
    TCtrlArranger.RightOf(fLVFavs, 8)
  );
  TCtrlArranger.MoveBelow(fLVFavs, chkNewTab, 8);
  pnlBody.ClientWidth := TCtrlArranger.TotalControlWidth(pnlBody) + 4;
  pnlBody.ClientHeight := TCtrlArranger.TotalControlHeight(pnlBody);
  inherited;
  TCtrlArranger.AlignLefts([pnlBody, lblTransparency]);
  TCtrlArranger.MoveToRightOf(lblTransparency, tbTransparency, 4);
  TCtrlArranger.AlignTops([btnClose, lblTransparency, tbTransparency]);
end;

class procedure TFavouritesDlg.Close;
begin
  if IsDisplayed then
    FreeAndNil(fInstance);
end;

procedure TFavouritesDlg.ConfigForm;
begin
  inherited;
  fFavourites.AddListener(FavouritesListener);
  TTrackBarHack(tbTransparency).OnMouseDown := TBTransparencyMouseDown;
  TTrackBarHack(tbTransparency).OnMouseUp := TBTransparencyMouseUp;
end;

procedure TFavouritesDlg.CreateLV;
resourcestring
  sSnippetName = 'Snippet';
  sLastAccessed = 'Last used';
begin
  fLVFavs := TListViewEx.Create(Self);
  with fLVFavs do
  begin
    Parent := pnlBody;
    Height := 240;
    Width := 360;
    HideSelection := False;
    ReadOnly := True;
    RowSelect := True;
    TabOrder := 0;
    TabStop := True;
    ViewStyle := vsReport;
    SortImmediately := False;
    with Columns.Add do
    begin
      Caption := sSnippetName;
      Width := 180;
    end;
    with Columns.Add do
    begin
      Caption := sLastAccessed;
      Width := 140;
    end;
    OnDblClick := LVDoubleClick;
    OnCompare := LVFavouritesCompare;
    OnCreateItemClass := LVFavouriteCreateItemClass;
    OnCustomDrawItem := LVCustomDrawItem;
    OnCustomDrawSubItem := LVCustomDrawSubItem;
  end;
end;

class procedure TFavouritesDlg.Display(AOwner: TComponent;
  const Favourites: TFavourites; Notifier: INotifier);
begin
  if not Assigned(fInstance) then
    fInstance := Create(AOwner);
  fInstance.fFavourites := Favourites;
  fInstance.fNotifier := Notifier;
  if not fInstance.Visible then
  begin
    fInstance.Show;
  end;
  fInstance.SetFocus;
end;

procedure TFavouritesDlg.FadeIn;
begin
  FadeTo(High(Byte));
end;

procedure TFavouritesDlg.FadeOut;
begin
  FadeTo(tbTransparency.Position);
end;

procedure TFavouritesDlg.FadeTo(const EndTransparency: Byte);
var
  Step: Int8;
begin
  Step := -1;
  if AlphaBlendValue < EndTransparency then
    Step := -Step;
  while AlphaBlendValue <> EndTransparency do
  begin
    AlphaBlendValue := AlphaBlendValue + Step;
    Sleep(2);
  end;
end;

procedure TFavouritesDlg.FavouritesListener(Sender: TObject;
  const EvtInfo: IInterface);
var
  Evt: IFavouritesChangeEventInfo;
  SelectedSnippet: TSnippetID;
  HaveSelection: Boolean;
begin
  Evt := EvtInfo as IFavouritesChangeEventInfo;
  case Evt.Action of
    cnAdded:
    begin
      HaveSelection := Assigned(fLVFavs.Selected);
      if HaveSelection then
        SelectedSnippet :=
          (fLVFavs.Selected as TFavouriteListItem).Favourite.SnippetID;
      AddLVItem(Evt.Favourite);
      ReSortLV;
      if HaveSelection then
        fLVFavs.Selected := FindListItem(SelectedSnippet);
    end;
    cnRemoved:
    begin
      HaveSelection := Assigned(fLVFavs.Selected);
      if HaveSelection then
        SelectedSnippet :=
          (fLVFavs.Selected as TFavouriteListItem).Favourite.SnippetID;
      RemoveLVItem(Evt.Favourite);
      ReSortLV;
      if HaveSelection and (Evt.Favourite.SnippetID <> SelectedSnippet) then
        fLVFavs.Selected := FindListItem(SelectedSnippet);
    end;
  end;
end;

function TFavouritesDlg.FindListItem(const SnippetID: TSnippetID): TListItem;
var
  LI: TListItem;
begin
  for LI in fLVFavs.Items do
  begin
    if (LI as TFavouriteListItem).Favourite.SnippetID = SnippetID then
      Exit(LI);
  end;
  Result := nil;
end;

procedure TFavouritesDlg.FormActivate(Sender: TObject);
begin
  FadeIn;
end;

procedure TFavouritesDlg.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  inherited;
  fInstance := nil;
  Action := caFree;
end;

procedure TFavouritesDlg.FormCreate(Sender: TObject);
begin
  inherited;
  CreateLV;
  fOptions := TPersistentOptions.Create;
  fWindowSettings := TDlgWindowSettings.CreateStandAlone(Self);
  AlphaBlendValue := High(Byte);
end;

procedure TFavouritesDlg.FormDeactivate(Sender: TObject);
begin
  FadeOut;
end;

procedure TFavouritesDlg.FormDestroy(Sender: TObject);
begin
  fFavourites.RemoveListener(FavouritesListener);
  fOptions.DisplayInNewTabs := chkNewTab.Checked;
  fOptions.InactiveAlphaBlendValue := tbTransparency.Position;
  fOptions.Free;
  fWindowSettings.Save;
  inherited;
end;

procedure TFavouritesDlg.InitForm;
begin
  inherited;
  fWindowSettings.Restore;
  PopulateLV;
  chkNewTab.Checked := fOptions.DisplayInNewTabs;
  tbTransparency.OnChange := nil;
  tbTransparency.Position := fOptions.InactiveAlphaBlendValue;
  tbTransparency.OnChange := tbTransparencyChange;
end;

class function TFavouritesDlg.IsDisplayed: Boolean;
begin
  Result := Assigned(fInstance) and fInstance.Visible;
end;

procedure TFavouritesDlg.LVCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
var
  UserDefined: Boolean;
begin
  UserDefined := (Item as TFavouriteListItem).Favourite.SnippetID.UserDefined;
  fLVFavs.Canvas.Font.Color := Preferences.DBHeadingColours[UserDefined];
end;

procedure TFavouritesDlg.LVCustomDrawSubItem(Sender: TCustomListView;
  Item: TListItem; SubItem: Integer; State: TCustomDrawState;
  var DefaultDraw: Boolean);
begin
  fLVFavs.Canvas.Font.Color := clNone;  // required to force later colour change
  fLVFavs.Canvas.Font.Color := clWindowText;
end;

procedure TFavouritesDlg.LVDoubleClick(Sender: TObject);
begin
  actDisplay.Execute;
end;

procedure TFavouritesDlg.LVFavouriteCreateItemClass(Sender: TCustomListView;
  var ItemClass: TListItemClass);
begin
  ItemClass := TFavouriteListItem;
end;

procedure TFavouritesDlg.LVFavouritesCompare(Sender: TObject; Item1,
  Item2: TListItem; Data: Integer; var Compare: Integer);
var
  Fav1, Fav2: TFavourite;
begin
  Fav1 := (Item1 as TFavouriteListItem).Favourite;
  Fav2 := (Item2 as TFavouriteListItem).Favourite;
  case fLVFavs.SortColumn of
    0:
      Compare := Fav1.SnippetID.CompareTo(Fav2.SnippetID);
    1:
      Compare := CompareDateTime(Fav1.LastAccessed, Fav2.LastAccessed);
  end;
  if fLVFavs.SortOrder = soDown then
    Compare := -Compare;
end;

procedure TFavouritesDlg.PopulateLV;
var
  Fav: TFavourite;
begin
  fLVFavs.Clear;
  for Fav in fFavourites do
    AddLVItem(Fav);
  fLVFavs.Selected := nil;
  ReSortLV;
end;

procedure TFavouritesDlg.RemoveLVItem(const Favourite: TFavourite);
var
  LI: TListItem;
begin
  for LI in fLVFavs.Items do
  begin
    if (LI as TFavouriteListItem).Favourite.SnippetID = Favourite.SnippetID then
    begin
      LI.Free;
      Exit;
    end;
  end;
end;

procedure TFavouritesDlg.ReSortLV;
begin
  if fLVFavs.SortColumn <> -1 then
    fLVFavs.CustomSort(nil, fLVFavs.SortColumn);
end;

procedure TFavouritesDlg.tbTransparencyChange(Sender: TObject);
begin
  if fTrackBarKeyDown or fTrackBarMouseDown then
    AlphaBlendValue := tbTransparency.Position;
end;

procedure TFavouritesDlg.tbTransparencyKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  fTrackBarKeyDown := True;
  FadeOut;
end;

procedure TFavouritesDlg.tbTransparencyKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  FadeIn;
  fTrackBarKeyDown := False;
end;

procedure TFavouritesDlg.TBTransparencyMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FadeOut;
  fTrackBarMouseDown := True;
end;

procedure TFavouritesDlg.TBTransparencyMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  fTrackBarMouseDown := False;
  FadeIn;
end;

{ TFavouritesDlg.TPersistentOptions }

constructor TFavouritesDlg.TPersistentOptions.Create;
var
  Section: ISettingsSection;
begin
  inherited Create;
  Section := Settings.ReadSection(ssFavourites);
  fDisplayInNewTabs := Boolean(
    StrToIntDef(Section.ItemValues['DisplayInNewTabs'], Ord(False))
  );
  fInactiveAlphaBlendValue := StrToIntDef(
    Section.ItemValues['InactiveAlphaBlendValue'], 160)
  ;
end;

destructor TFavouritesDlg.TPersistentOptions.Destroy;
var
  Section: ISettingsSection;
begin
  Section := Settings.EmptySection(ssFavourites);
  Section.ItemValues['DisplayInNewTabs'] := IntToStr(Ord(fDisplayInNewTabs));
  Section.ItemValues['InactiveAlphaBlendValue'] := IntToStr(
    fInactiveAlphaBlendValue
  );
  Section.Save;
  inherited;
end;

end.

