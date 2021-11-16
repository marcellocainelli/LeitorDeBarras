unit LeitorBarras;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Media, FMX.Platform, FMX.DialogService,
  ZXing.BarcodeFormat,
  ZXing.ReadResult,
  System.Permissions,
  {$IFDEF ANDROID}
    Androidapi.Helpers,
    Androidapi.JNI.JavaTypes,
    Androidapi.JNI.Os,
  {$ENDIF}
  ZXing.ScanManager, FMX.Layouts;

type
  TformLeitorBarras = class(TForm)
    CameraComponent: TCameraComponent;
    Layout1: TLayout;
    imgCamera: TImage;
    lytTop: TLayout;
    lytBtnFechar: TLayout;
    pthBtnFechar: TPath;
    speBtnFechar: TSpeedButton;
    lblMsg: TLabel;
    procedure CameraComponentSampleBufferReady(Sender: TObject;
      const ATime: TMediaTime);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure speBtnFecharClick(Sender: TObject);
  private
    FCodigo: String;
    FScanInProgress: Boolean;
    FFrameTake: Integer;
    FScanBitmap: TBitmap;
    procedure ProcessarImagem;
    procedure ParseImage;
    procedure ConfiguraCamera;

    procedure CameraPermissionRequestResult(Sender: TObject; const APermissions: TClassicStringDynArray; const AGrantResults: TClassicPermissionStatusDynArray);
    function AppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;

  public
    { Public declarations }
    property Codigo: String read FCodigo write FCodigo;
  end;

var
  formLeitorBarras: TformLeitorBarras;

implementation

{$R *.fmx}

{ TForm1 }

function TformLeitorBarras.AppEvent(AAppEvent: TApplicationEvent;
  AContext: TObject): Boolean;
begin
  case AAppEvent of
    TApplicationEvent.WillBecomeInactive, TApplicationEvent.EnteredBackground, TApplicationEvent.WillTerminate:
      CameraComponent.Active:= false;
  end;
end;

procedure TformLeitorBarras.CameraComponentSampleBufferReady(Sender: TObject;
  const ATime: TMediaTime);
begin
  ProcessarImagem;
end;

procedure TformLeitorBarras.CameraPermissionRequestResult(Sender: TObject;
  const APermissions: TClassicStringDynArray;
  const AGrantResults: TClassicPermissionStatusDynArray);
begin
  if (Length(AGrantResults) = 1) and
    (AGrantResults[0] = TPermissionStatus.Granted) then
  begin
    ConfiguraCamera
  end else
    TDialogService.ShowMessage('Cannot scan for barcodes because the required permissions is not granted');
end;

procedure TformLeitorBarras.ConfiguraCamera;
begin
  CameraComponent.Active := False;
  CameraComponent.Quality := FMX.Media.TVideoCaptureQuality.MediumQuality;
  CameraComponent.Kind := FMX.Media.TCameraKind.BackCamera;
  CameraComponent.FocusMode := FMX.Media.TFocusMode.ContinuousAutoFocus;
  CameraComponent.Active := True;
end;

procedure TformLeitorBarras.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  CameraComponent.Active:= False;
  if Assigned(FScanBitmap) then
    FreeAndNil(FScanBitmap);
end;

procedure TformLeitorBarras.FormCreate(Sender: TObject);
var
  AppEventSvc: IFMXApplicationEventService;
begin
  if TPlatformServices.Current.SupportsPlatformService
    (IFMXApplicationEventService, IInterface(AppEventSvc)) then begin
    AppEventSvc.SetApplicationEventHandler(AppEvent);
  end;
  FFrameTake:= 0;
end;

procedure TformLeitorBarras.FormShow(Sender: TObject);
var
  FCamera: string;
begin
  {$IFDEF ANDROID}
  FCamera:= JStringToString(TJManifest_permission.JavaClass.CAMERA);
  PermissionsService.RequestPermissions([FCamera], CameraPermissionRequestResult, nil);
  {$ELSE}
  ConfiguraCamera;
  {$ENDIF}
end;

procedure TformLeitorBarras.ParseImage;
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      vReadResult: TReadResult;
      vScanManager: TScanManager;
    begin
      try
        FScanInProgress := True;
        vScanManager := TScanManager.Create(TBarcodeFormat.Auto, nil);
        try
          vReadResult := vScanManager.Scan(FScanBitmap);
        except
          on E: Exception do begin
            TThread.Synchronize(TThread.CurrentThread,
              procedure
              begin
                //label1.Text := E.Message;
              end);
            exit;
          end;
        end;
        TThread.Synchronize(TThread.CurrentThread,
          procedure
          begin
            if (vReadResult <> nil) then begin
              CameraComponent.Active:= False;
              FCodigo:= vReadResult.Text;
              Close;
            end;
          end);
      finally
        if vReadResult <> nil then
          FreeAndNil(vReadResult);
        vScanManager.Free;
        FScanInProgress:= False;
      end;
    end).Start();
end;

procedure TformLeitorBarras.ProcessarImagem;
var
  vReadResult: TReadResult;
begin
  TThread.Synchronize(TThread.CurrentThread,
  procedure
  begin
    CameraComponent.SampleBufferToBitmap(imgCamera.Bitmap, True);
    if FScanInProgress then
      exit;
    inc(FFrameTake);
    if (FFrameTake mod 4 <> 0) then begin
      exit;
    end;
    FScanBitmap:= TBitmap.Create;
    FScanBitmap.Assign(imgCamera.Bitmap);
    ParseImage;
  end);
end;

procedure TformLeitorBarras.speBtnFecharClick(Sender: TObject);
begin
  Close;
end;

end.
