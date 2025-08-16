unit uMain;

interface

uses
  Winapi.Windows,
  Winapi.Messages,

  System.SysUtils,
  System.Classes,
  System.Types,

  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs;

type
  TfrmMain = class(TForm)
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
  private
    FBackBuffer: TBitmap;
    FCurrentPoint: TPoint;
    FDrawing: Boolean;
    FPermanentLines: TList;
    FStartPoint: TPoint;

    procedure DrawSmoothCurve(Canvas: TCanvas; StartPt, EndPt: TPoint; Color: TColor; Width: Integer; Temporary: Boolean = False);
    procedure InitializeBackBuffer;
    procedure UpdateDisplay;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  // 저장된 곡선 정보
  PCurveInfo = ^TCurveInfo;
  TCurveInfo = record
    StartPoint: TPoint;
    EndPoint: TPoint;
    Color: TColor;
    Width: Integer;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

uses
  System.Math;

{ TfrmMain }

constructor TfrmMain.Create(AOwner: TComponent);
begin
  inherited;

  // 더블 버퍼링 활성화
  DoubleBuffered := True;

  // 백 버퍼 초기화
  InitializeBackBuffer;

  // 영구 선 목록 초기화
  FPermanentLines := TList.Create;

  FDrawing := False;

  // 마우스 이벤트 캡처를 위한 설정
  Color := clWhite;
end;

destructor TfrmMain.Destroy;
var
  i: Integer;
begin
  // 메모리 해제
  if Assigned(FPermanentLines) then
  begin
    for i := 0 to FPermanentLines.Count - 1 do
      Dispose(PCurveInfo(FPermanentLines[i]));

    FPermanentLines.Free;
  end;

  if Assigned(FBackBuffer) then
    FBackBuffer.Free;

  inherited;
end;

procedure TfrmMain.DrawSmoothCurve(Canvas: TCanvas; StartPt, EndPt: TPoint; Color: TColor; Width: Integer; Temporary: Boolean);
var
  LPoints: array[0..3] of TPoint;
  LControlOffset: Integer;
  LDistance: Double;
begin
  Canvas.Pen.Color := Color;
  Canvas.Pen.Width := Width;

  // 임시 곡선은 반투명하게
  if Temporary then
  begin
    Canvas.Pen.Color := RGB(
      GetRValue(Color) + (255 - GetRValue(Color)) div 2,
      GetGValue(Color) + (255 - GetGValue(Color)) div 2,
      GetBValue(Color) + (255 - GetBValue(Color)) div 2
    );
  end;

  // 두 점 사이의 거리 계산
  LDistance := Sqrt(Sqr(EndPt.X - StartPt.X) + Sqr(EndPt.Y - StartPt.Y));

  // 거리가 너무 짧으면 직선으로
  if LDistance < 10 then
  begin
    Canvas.MoveTo(StartPt.X, StartPt.Y);
    Canvas.LineTo(EndPt.X, EndPt.Y);

    Exit;
  end;

  // 제어점 오프셋 계산 (거리에 비례)
  LControlOffset := Round(LDistance / 4);
  if LControlOffset > 100 then
    LControlOffset := 100;

  // 베지어 곡선의 4개 점 설정
  // 시작점
  LPoints[0] := StartPt;

  // 제어점 1: 시작점에서 수평으로 이동
  LPoints[1] := Point(StartPt.X + LControlOffset, StartPt.Y);

  // 제어점 2: 끝점에서 수평으로 역방향 이동
  LPoints[2] := Point(EndPt.X - LControlOffset, EndPt.Y);

  // 끝점
  LPoints[3] := EndPt;

  // 베지어 곡선 그리기
  Canvas.PolyBezier(LPoints);
end;

procedure TfrmMain.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FDrawing := True;
    FStartPoint := Point(X, Y);
    FCurrentPoint := Point(X, Y);

    // 마우스 캡처
    SetCapture(Handle);
  end;
end;

procedure TfrmMain.FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if FDrawing then
  begin
    FCurrentPoint := Point(X, Y);
    UpdateDisplay;
  end;
end;

procedure TfrmMain.FormMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LInfo: PCurveInfo;
begin
  if (Button = mbLeft) and FDrawing then
  begin
    FDrawing := False;

    // 마우스 캡처 해제
    ReleaseCapture;

    // 최종 곡선을 영구 저장
    New(LInfo);

    LInfo^.StartPoint := FStartPoint;
    LInfo^.EndPoint := Point(X, Y);
    LInfo^.Color := clBlue;
    LInfo^.Width := 2;

    FPermanentLines.Add(LInfo);

    // 백 버퍼에 영구 곡선 그리기
    DrawSmoothCurve(FBackBuffer.Canvas, FStartPoint, Point(X, Y), clBlue, 2, False);

    // 화면 갱신
    Invalidate;
  end;
end;

procedure TfrmMain.FormPaint(Sender: TObject);
begin
  if FDrawing then
    UpdateDisplay
  else
  begin
    // 백 버퍼의 내용을 화면에 복사
    Canvas.CopyRect(
      Rect(0, 0, ClientWidth, ClientHeight),
      FBackBuffer.Canvas,
      Rect(0, 0, ClientWidth, ClientHeight)
    );
  end;
end;

procedure TfrmMain.InitializeBackBuffer;
begin
  if Assigned(FBackBuffer) then
    FBackBuffer.Free;

  FBackBuffer := TBitmap.Create;
  FBackBuffer.Width := ClientWidth;
  FBackBuffer.Height := ClientHeight;
  FBackBuffer.Canvas.Brush.Color := clWhite;
  FBackBuffer.Canvas.FillRect(Rect(0, 0, ClientWidth, ClientHeight));
end;

procedure TfrmMain.UpdateDisplay;
var
  LBitmap: TBitmap;
begin
  // 임시 비트맵 생성
  LBitmap := TBitmap.Create;
  try
    LBitmap.Width := ClientWidth;
    LBitmap.Height := ClientHeight;

    // 백 버퍼 복사 (영구 곡선들)
    LBitmap.Canvas.CopyRect(
      Rect(0, 0, ClientWidth, ClientHeight),
      FBackBuffer.Canvas,
      Rect(0, 0, ClientWidth, ClientHeight)
    );

    // 현재 그리는 중인 임시 곡선 추가
    if FDrawing then
    begin
      DrawSmoothCurve(LBitmap.Canvas, FStartPoint, FCurrentPoint, clRed, 2, True);

      // 시작점과 현재점 표시
      LBitmap.Canvas.Brush.Color := clGreen;
      LBitmap.Canvas.Ellipse(FStartPoint.X - 3, FStartPoint.Y - 3,
                                FStartPoint.X + 3, FStartPoint.Y + 3);

      LBitmap.Canvas.Brush.Color := clRed;
      LBitmap.Canvas.Ellipse(FCurrentPoint.X - 3, FCurrentPoint.Y - 3,
                                FCurrentPoint.X + 3, FCurrentPoint.Y + 3);
    end;

    // 화면에 출력
    Canvas.CopyRect(
      Rect(0, 0, ClientWidth, ClientHeight),
      LBitmap.Canvas,
      Rect(0, 0, ClientWidth, ClientHeight)
    );

  finally
    LBitmap.Free;
  end;
end;

end.
