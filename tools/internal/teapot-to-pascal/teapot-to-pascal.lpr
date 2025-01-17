{
  Copyright 2010-2022 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Convert teapot VRML file teapot.wrl into Pascal source file
  with 4 Teapot constants.
  This way we get Utah teapot coordinate data in Pascal. }

uses SysUtils, X3DNodes, X3DLoad;

var
  Model: TX3DNode;

  procedure HandleCoords(const BlenderName, PascalName: string);
  var
    G: TGroupNode;
    IFS: TIndexedFaceSetNode;
    C: TCoordinateNode;
    I: Integer;
    Merged: Cardinal;
  begin
    { We know how a VRML file generated by Blender looks like, so we simply assume
      in the code below that it's as expected (1st child of the Group is a Shape etc.).
      In case of problems, we can simply fail with an exception. }
    G := Model.FindNodeByName(TGroupNode, 'ME_' + BlenderName, false) as TGroupNode;
    IFS := (G.FdChildren[0] as TShapeNode).FdGeometry.Value as TIndexedFaceSetNode;
    C := IFS.FdCoord.Value as TCoordinateNode;

    Merged := C.FdPoint.Items.MergeCloseVertexes(0.001);
    Writeln(ErrOutput, 'Merged close vertexes on mesh ', BlenderName, ': ', Merged, ' changed.');

    Writeln('Teapot' + PascalName + 'Coord: array [0..', C.FdPoint.Count - 1, '] of TVector3 = (');
    for I := 0 to C.FdPoint.Count - 1 do
    begin
      Write(Format('(X: %g; Y: %g; Z: %g))', [
        C.FdPoint.Items.L[I][0],
        C.FdPoint.Items.L[I][1],
        C.FdPoint.Items.L[I][2] ]));
      if I < C.FdPoint.Count - 1 then Write(',');
      Writeln;
    end;
    Writeln(');');

    Writeln('Teapot' + PascalName + 'CoordIndex: array [0..', IFS.FdCoordIndex.Count - 1, '] of LongInt = (');
    for I := 0 to IFS.FdCoordIndex.Count - 1 do
    begin
      Write(IFS.FdCoordIndex.Items[I]);
      if I < IFS.FdCoordIndex.Count - 1 then Write(', ');
      if IFS.FdCoordIndex.Items[I] < 0 then Writeln;
    end;
    Writeln(');');
  end;

begin
  Model := LoadNode('teapot.wrl');
  try
    HandleCoords('TeapotManifold', 'Manifold');
    HandleCoords('Teapot', '');
  finally FreeAndNil(Model) end;
end.
