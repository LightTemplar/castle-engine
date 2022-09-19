{
  Copyright 2020-2022 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Third-person navigation (TCastleThirdPersonNavigation). }
unit CastleThirdPersonNavigation;

{$I castleconf.inc}

interface

uses SysUtils, Classes,
  CastleKeysMouse, CastleScene, CastleVectors, CastleCameras,
  CastleTransform, CastleInputs, CastleClassUtils;

type
  { Used by TCastleThirdPersonNavigation.AimAvatar. }
  TAimAvatar = (aaNone, aaHorizontal, aaFlying);

  TMovementType = (mtVelocity, mtForce); // only Velocity available currently

  { 3rd-person camera navigation.
    Create an instance of this and assign it to @link(TCastleViewport.Navigation) to use.
    Be sure to also assign @link(Avatar).
    Call @link(Init) once the parameters that determine initial camera location are all set.

    Turn on @link(MouseLook TCastleNavigation.MouseLook) to allow user to move
    the mouse to orbit with the camera around the avatar.
    When AimAvatar is aaNone (default), it allows to look at the avatar easily
    from any side (e.g. you can then see avatar's face easily).
    When @link(AimAvatar) is aaHorizontal or aaFlying, rotating allows to point
    the avatar at the appropriate direction.

    Using keys AWSD and arrows you can move and rotate the avatar,
    and the camera will follow.

    Using the mouse wheel you can get closer / further to the avatar.

    See also the news post with demo movie about this component:
    https://castle-engine.io/wp/2020/06/29/third-person-navigation-with-avatar-component-in-castle-game-engine/
  }
  TCastleThirdPersonNavigation = class(TCastleMouseLookNavigation)
  strict private
    FAvatar: TCastleScene;
    FAvatarHierarchy: TCastleTransform;
    FAvatarRotationSpeed: Single;
    FInitialHeightAboveTarget: Single;
    FDistanceToAvatarTarget: Single;
    FAimAvatar: TAimAvatar;
    FAvatarTarget: TVector3;
    FCameraSpeed: Single;
    {$ifdef AVATAR_TARGET_FORWARD}
    FAvatarTargetForward: TVector3;
    {$endif}
    FMoveSpeed, FCrouchSpeed, FRunSpeed, FJumpSpeed: Single;
    FRotationSpeed: Single;
    FInput_Forward: TInputShortcut;
    FInput_Backward: TInputShortcut;
    FInput_RightRotate: TInputShortcut;
    FInput_LeftRotate: TInputShortcut;
    FInput_RightStrafe: TInputShortcut;
    FInput_LeftStrafe: TInputShortcut;
    FInput_CameraCloser: TInputShortcut;
    FInput_CameraFurther: TInputShortcut;
    FInput_Crouch: TInputShortcut;
    FInput_Run: TInputShortcut;
    FInput_Jump: TInputShortcut;
    FCameraDistanceChangeSpeed: Single;
    FMinDistanceToAvatarTarget: Single;
    FMaxDistanceToAvatarTarget: Single;
    FImmediatelyFixBlockedCamera: Boolean;
    FAnimationIdle: String;
    FAnimationRotate: String;
    FAnimationWalk: String;
    FAnimationRun: String;
    FAnimationCrouch: String;
    FAnimationCrouchIdle: String;
    FAnimationCrouchRotate: String;
    FAnimationJump: String;
    FAnimationFall: String;
    FCameraFollows: Boolean;
    FAvatarFreeObserver: TFreeNotificationObserver;
    FAvatarHierarchyFreeObserver: TFreeNotificationObserver;
    SetAnimationWarningsDone: Cardinal;
    FMovementType: TMovementType;
    FWasJumpInput: Boolean;
    { Zero we can't control avatar in air, one we have full control }
    FAirMovementControl: Single;
    FAirRotationControl: Single;
    function RealAvatarHierarchy: TCastleTransform;
    procedure SetAvatar(const Value: TCastleScene);
    procedure SetAvatarHierarchy(const Value: TCastleTransform);
    function CameraPositionInitial(const A: TCastleTransform): TVector3; overload;
    function CameraPositionInitial(const A: TCastleTransform; out TargetWorldPos: TVector3): TVector3; overload;
    { Returns MaxSingle if no limit.
      Note that CameraDir doesn't have to be normalized. }
    function CameraMaxDistanceToTarget(const A: TCastleTransform; const CameraLookPos: TVector3;
      const CameraDir: TVector3): Single;
    { Update camera, to avoid having something collidable between camera position and AvatarTarget.
      Note that CameraDir doesn't have to be normalized. }
    procedure FixCameraForCollisions(var CameraPos: TVector3; const CameraDir: TVector3);
    { Return V rotated such that it is
      orthogonal to GravUp. This way it returns V projected
      on the gravity horizontal plane.
      Result retains the V length (so it is always normalized if V is normalized).

      Note that when V and GravUp are parallel,
      this just returns current V --- because in such case
      we can't project V on the horizontal plane. }
    function ToGravityPlane(const V: TVector3; const GravUp: TVector3): TVector3;
    function AnimationIdleStored: Boolean;
    function AnimationRotateStored: Boolean;
    function AnimationWalkStored: Boolean;
    function AnimationRunStored: Boolean;
    function AnimationCrouchStored: Boolean;
    function AnimationCrouchIdleStored: Boolean;
    function AnimationCrouchRotateStored: Boolean;
    function AnimationJumpStored: Boolean;
    function AnimationFallStored: Boolean;
    { Change Avatar.AutoAnimation to the 1st animation that is possible. }
    procedure SetAnimation(const AnimationNames: array of String);
    procedure SetInitialHeightAboveTarget(const Value: Single);
    procedure SetDistanceToAvatarTarget(const Value: Single);
    procedure MySetAvatarTargetForPersistent(const AValue: TVector3);
    procedure SetCameraFollows(const Value: Boolean);
    procedure AvatarFreeNotification(const Sender: TFreeNotificationObserver);
    procedure AvatarHierarchyFreeNotification(const Sender: TFreeNotificationObserver);
    function MovementControlFactor(const AvatarOnGround: Boolean): Single;
    function RotationControlFactor(const AvatarOnGround: Boolean): Single;
  protected
    procedure ProcessMouseLookDelta(const Delta: TVector2); override;
  public
    const
      DefaultInitialHeightAboveTarget = 1.0;
      DefaultDistanceToAvatarTarget = 4.0;
      DefaultAvatarRotationSpeed = 10;
      DefaultAvatarTarget: TVector3 = (X: 0; Y: 2; Z: 0);
      DefaultCameraSpeed = 10;
      {$ifdef AVATAR_TARGET_FORWARD}
      DefaultAvatarTargetForward: TVector3 = (X: 0; Y: 2; Z: 0);
      {$endif}
      DefaultMoveSpeed = 1.0;
      DefaultCrouchSpeed = 0.5;
      DefaultRunSpeed = 2.0;
      DefaultJumpSpeed = 5.0;
      DefaultRotationSpeed = Pi * 150 / 180;
      DefaultCameraDistanceChangeSpeed = 1;
      DefaultMinDistanceToAvatarTarget = 0.5;
      DefaultMaxDistanceToAvatarTarget = 10;
      DefaultAnimationIdle = 'idle';
      DefaultAnimationRotate = 'rotate';
      DefaultAnimationWalk = 'walk';
      DefaultAnimationRun = 'run';
      DefaultAnimationCrouch = 'crouch';
      DefaultAnimationCrouchIdle = 'crouch_idle';
      DefaultAnimationCrouchRotate = 'crouch_rotate';
      DefaultAnimationJump = 'jump';
      DefaultAnimationFall = 'fall';
      DefaultAirMovementControl = 0.5;
      DefaultAirRotationControl = 0.5;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Update(const SecondsPassed: Single;
      var HandleInput: Boolean); override;
    function Press(const Event: TInputPressRelease): Boolean; override;
    function PropertySections(const PropertyName: String): TPropertySections; override;

    { Makes camera be positioned with respect to the current properties and avatar.
      Always call this explicitly once.
      Use this after setting properties like @link(Avatar),
      @link(AvatarHierarchy), @link(DistanceToAvatarTarget),
      @link(InitialHeightAboveTarget).

      At design-time (in CGE editor), this is automatically called after
      changing relevant properties of this navigation. }
    procedure Init;

    { Translation, from the avatar origin, to the "target" of the avatar where camera
      looks at. This is usually head, and this vector should just describe the height
      of head above the ground.
      By default this is DefaultAvatarTarget = (0, 2, 0). }
    property AvatarTarget: TVector3 read FAvatarTarget write FAvatarTarget;

    {$ifdef AVATAR_TARGET_FORWARD}
    { When the camera looks directly behind the avatar's back,
      it points at AvatarTargetForward, not AvatarTarget.
      This allows to place AvatarTargetForward more in forward (and maybe higher/lower)
      than avatar's head.
      This allows to look more "ahead".

      The effective target is a result of lerp between
      AvatarTargetForward and AvatarTarget, depending on how much is camera now close to
      the initial position "looking from the back of avatar".

      The camera is still always rotating around AvatarTarget
      (so you rotate around avatar's head, even if you look far ahead).
      By default this is DefaultAvatarTargetForward = (0, 2, 0).

      TODO: Not implemented now. I made initial implementation using Lerp,
      and it just works awful -- camera rotates unexpectedly, the user feels
      losing control of the camera at certain angles.
    }
    property AvatarTargetForward: TVector3 read FAvatarTargetForward write FAvatarTargetForward;
    {$endif}

    property Input_Forward: TInputShortcut read FInput_Forward;
    property Input_Backward: TInputShortcut read FInput_Backward;
    property Input_LeftRotate: TInputShortcut read FInput_LeftRotate;
    property Input_RightRotate: TInputShortcut read FInput_RightRotate;
    property Input_LeftStrafe: TInputShortcut read FInput_LeftStrafe;
    property Input_RightStrafe: TInputShortcut read FInput_RightStrafe;
    property Input_CameraCloser: TInputShortcut read FInput_CameraCloser;
    property Input_CameraFurther: TInputShortcut read FInput_CameraFurther;
    property Input_Crouch: TInputShortcut read FInput_Crouch;
    property Input_Run: TInputShortcut read FInput_Run;
    property Input_Jump: TInputShortcut read FInput_Jump;
  published
    property MouseLookHorizontalSensitivity;
    property MouseLookVerticalSensitivity;
    property InvertVerticalMouseLook;

    { Does camera follow the avatar, by default yes.

      When this is @false, camera remains unchanged by anything here
      (avatar movement/rotations, mouse look, even by calling @link(Init)).
      Some properties of this then are meaningless (e.g. @link(DistanceToAvatarTarget)).

      However, all the inputs to control the avatar continue to work. }
    property CameraFollows: Boolean read FCameraFollows write SetCameraFollows default true;

    { Avatar scene, that is animated, moved and rotated when this navigation changes.
      This navigation component will just call @code(Avatar.AutoAnimation := 'xxx') when necessary.
      Currently we require the following animations to exist: walk, idle.

      When AvatarHierarchy is @nil, then @name is directly moved and rotated
      to move avatar.
      Otherwise, AvatarHierarchy is moved, and @name should be inside AvatarHierarchy.

      This scene should be part of @link(TCastleViewport.Items)
      to make this navigation work, in particular when you call @link(Init). }
    property Avatar: TCastleScene read FAvatar write SetAvatar;

    { Optional avatar hierarchy that is moved and rotated when this navigation changes.
      When this is @nil, we just move and rotate the @link(Avatar).
      When this is non-nil, then we only move and rotate this AvatarHierarchy.

      If @link(AvatarHierarchy) is non-nil, then it should contain
      @link(Avatar) as a child. @link(AvatarHierarchy) can even be equal to @link(Avatar)
      (it is equivalent to just leaving @link(AvatarHierarchy) as @nil).

      This object should be part of @link(TCastleViewport.Items)
      to make this navigation work, in particular when you call @link(Init). }
    property AvatarHierarchy: TCastleTransform read FAvatarHierarchy write SetAvatarHierarchy;

    { When @link(AimAvatar), this is avatar's rotation speed (in radians per second).
      Should make avatar rotation "catch up" (with some delay after camera rotation. }
    property AvatarRotationSpeed: Single read FAvatarRotationSpeed write FAvatarRotationSpeed
      {$ifdef FPC}default DefaultAvatarRotationSpeed{$endif};

    { Camera position tracks the desired position with given speed (in units per second).
      This makes camera adjust to avatar moving (because of input, or because of gravity
      or other external code) and to not being blocked by the collider. }
    property CameraSpeed: Single read FCameraSpeed write FCameraSpeed
      {$ifdef FPC}default DefaultCameraSpeed{$endif};

    { If not aaNone then rotating the camera also rotates (with some delay) the avatar,
      to face the same direction as the camera.
      This allows to rotate the avatar with mouse look (which is comfortable),
      on the other hand it takes away some flexibility,
      e.g. you cannot look at avatar's face for a long time anymore. }
    property AimAvatar: TAimAvatar read FAimAvatar write FAimAvatar default aaNone;

    { Initial height of camera above the AvatarTarget.
      Together with DistanceToAvatarTarget this determines the initial camera position,
      set by @link(Init).
      It is not used outside of @link(Init). }
    property InitialHeightAboveTarget: Single read FInitialHeightAboveTarget write SetInitialHeightAboveTarget
      {$ifdef FPC}default DefaultInitialHeightAboveTarget{$endif};

    { Immediately (not with delay of CameraSpeed) update camera to never block avatar
      view by a wall, enemy etc. When it is @true, we avoid seeing an invalid geometry
      (e.g. from the wrong side of the wall or inside a creature) @italic(ever),
      but in exchange the camera sometimes has to be adjusted very abrtupty (testcase:
      third_person_navigation demo, stand in the middle of moving enemies, and look around). }
    property ImmediatelyFixBlockedCamera: Boolean read FImmediatelyFixBlockedCamera write FImmediatelyFixBlockedCamera
      default false;

    { Preferred distance from camera to the avatar target (head).
      User can change it with Input_CameraCloser, Input_CameraFurther if you set these inputs
      to some key/mouse button/mouse wheel. }
    property DistanceToAvatarTarget: Single read FDistanceToAvatarTarget write SetDistanceToAvatarTarget
      {$ifdef FPC}default DefaultDistanceToAvatarTarget{$endif};
    { Speed with which Input_CameraCloser, Input_CameraFurther can change DistanceToAvatarTarget. }
    property CameraDistanceChangeSpeed: Single read FCameraDistanceChangeSpeed write FCameraDistanceChangeSpeed
      {$ifdef FPC}default DefaultCameraDistanceChangeSpeed{$endif};
    { Limit of the distance to avatar, used when changing DistanceToAvatarTarget,
      and also when deciding how to adjust camera to avoid collisions.
      @groupBegin }
    property MinDistanceToAvatarTarget: Single read FMinDistanceToAvatarTarget write FMinDistanceToAvatarTarget
      {$ifdef FPC}default DefaultMinDistanceToAvatarTarget{$endif};
    property MaxDistanceToAvatarTarget: Single read FMaxDistanceToAvatarTarget write FMaxDistanceToAvatarTarget
      {$ifdef FPC}default DefaultMaxDistanceToAvatarTarget{$endif};
    { @groupEnd }

    { Speed of movement by keys. }
    property MoveSpeed: Single read FMoveSpeed write FMoveSpeed
      {$ifdef FPC}default DefaultMoveSpeed{$endif};
    { Speed of movement by keys, when crouching. }
    property CrouchSpeed: Single read FCrouchSpeed write FCrouchSpeed
      {$ifdef FPC}default DefaultCrouchSpeed{$endif};
    { Speed of movement by keys, when running. }
    property RunSpeed: Single read FRunSpeed write FRunSpeed
      {$ifdef FPC}default DefaultRunSpeed{$endif};
    { Speed of jump by keys. }
    property JumpSpeed: Single read FJumpSpeed write FJumpSpeed
      {$ifdef FPC}default DefaultJumpSpeed{$endif};
    { Speed of rotating by keys, in radians per second. }
    property RotationSpeed: Single read FRotationSpeed write FRotationSpeed
      {$ifdef FPC}default DefaultRotationSpeed{$endif};
    { Should we have control on avatar movement in the air.

      - 0 - not
      - 1 - full control like on ground
      - between 0 - 1 - limited control
      - above 1 - faster than on ground }
    property AirMovementControl: Single read FAirMovementControl write FAirMovementControl
      {$ifdef FPC}default DefaultAirMovementControl{$endif};
    { Should we have control on avatar rotation in the air.

      - 0 - not
      - 1 - full control like on ground
      - between 0 - 1 - limited control
      - above 1 - faster than on ground }
    property AirRotationControl: Single read FAirRotationControl write FAirRotationControl
      {$ifdef FPC}default DefaultAirRotationControl{$endif};


    { Animation when character is not moving, not rotating and not crouching.
      Default 'idle'. }
    property AnimationIdle: String read FAnimationIdle write FAnimationIdle stored AnimationIdleStored nodefault;
    { Animation when character is rotating, but otherwise remains in place
      (not moving) and it is not crouching.
      Default 'rotate'. }
    property AnimationRotate: String read FAnimationRotate write FAnimationRotate stored AnimationRotateStored nodefault;
    { Animation when character is walking.
      Default 'walk'. }
    property AnimationWalk: String read FAnimationWalk write FAnimationWalk stored AnimationWalkStored nodefault;
    { Animation when character is running.
      Default 'run'. }
    property AnimationRun: String read FAnimationRun write FAnimationRun stored AnimationRunStored nodefault;
    { Animation when character is moving while crouching.
      Default 'crouch'. }
    property AnimationCrouch: String read FAnimationCrouch write FAnimationCrouch stored AnimationCrouchStored nodefault;
    { Animation when character is crouching (Input_Crouch is pressed) but not moving or rotating.
      Default 'crouch_idle'. }
    property AnimationCrouchIdle: String read FAnimationCrouchIdle write FAnimationCrouchIdle stored AnimationCrouchIdleStored nodefault;
    { Animation when character is crouching (Input_Crouch is pressed) and rotating, but not moving.
      Default 'crouch_rotate'.}
    property AnimationCrouchRotate: String read FAnimationCrouchRotate write FAnimationCrouchRotate stored AnimationCrouchRotateStored nodefault;
    { Animation when character is jumping (Input_Jump is pressed).
      Default 'jump'.}
    property AnimationJump: String read FAnimationJump write FAnimationJump stored AnimationJumpStored nodefault;
    { Animation when character is fall.
      Default 'fall'.}
    property AnimationFall: String read FAnimationFall write FAnimationFall stored AnimationFallStored nodefault;

    { Camera will keep at least this distance from walls. }
    property Radius;

  {$define read_interface_class}
  {$I auto_generated_persistent_vectors/tcastlethirdpersonnavigation_persistent_vectors.inc}
  {$undef read_interface_class}
  end;

implementation

uses Math,
  CastleUtils, CastleStringUtils, CastleComponentSerialize, CastleLog, CastleBoxes;

{ TCastleThirdPersonNavigation ----------------------------------------------- }

constructor TCastleThirdPersonNavigation.Create(AOwner: TComponent);
begin
  inherited;
  FCameraFollows := true;
  FAvatarTarget := DefaultAvatarTarget;
  {$ifdef AVATAR_TARGET_FORWARD}
  FAvatarTargetForward := DefaultAvatarTargetForward;
  {$endif}
  FAvatarRotationSpeed := DefaultAvatarRotationSpeed;
  FAimAvatar := aaNone;
  FCameraSpeed := DefaultCameraSpeed;
  FInitialHeightAboveTarget := DefaultInitialHeightAboveTarget;
  FDistanceToAvatarTarget := DefaultDistanceToAvatarTarget;
  FMoveSpeed := DefaultMoveSpeed;
  FCrouchSpeed := DefaultCrouchSpeed;
  FRunSpeed := DefaultRunSpeed;
  FJumpSpeed := DefaultJumpSpeed;
  FRotationSpeed := DefaultRotationSpeed;
  FCameraDistanceChangeSpeed := DefaultCameraDistanceChangeSpeed;
  FMinDistanceToAvatarTarget := DefaultMinDistanceToAvatarTarget;
  FMaxDistanceToAvatarTarget := DefaultMaxDistanceToAvatarTarget;
  FAnimationIdle := DefaultAnimationIdle;
  FAnimationRotate := DefaultAnimationRotate;
  FAnimationWalk := DefaultAnimationWalk;
  FAnimationRun := DefaultAnimationRun;
  FAnimationCrouch := DefaultAnimationCrouch;
  FAnimationCrouchIdle := DefaultAnimationCrouchIdle;
  FAnimationCrouchRotate := DefaultAnimationCrouchRotate;
  FAnimationJump := DefaultAnimationJump;
  FAnimationFall := DefaultAnimationFall;

  FAvatarFreeObserver := TFreeNotificationObserver.Create(Self);
  FAvatarFreeObserver.OnFreeNotification := {$ifdef FPC}@{$endif}AvatarFreeNotification;
  FAvatarHierarchyFreeObserver := TFreeNotificationObserver.Create(Self);
  FAvatarHierarchyFreeObserver.OnFreeNotification := {$ifdef FPC}@{$endif}AvatarHierarchyFreeNotification;

  FInput_Forward                 := TInputShortcut.Create(Self);
  FInput_Backward                := TInputShortcut.Create(Self);
  FInput_LeftRotate              := TInputShortcut.Create(Self);
  FInput_RightRotate             := TInputShortcut.Create(Self);
  FInput_LeftStrafe              := TInputShortcut.Create(Self);
  FInput_RightStrafe             := TInputShortcut.Create(Self);
  FInput_CameraCloser            := TInputShortcut.Create(Self);
  FInput_CameraFurther           := TInputShortcut.Create(Self);
  FInput_Crouch                  := TInputShortcut.Create(Self);
  FInput_Run                     := TInputShortcut.Create(Self);
  FInput_Jump                    := TInputShortcut.Create(Self);

  Input_Forward                 .Assign(keyW, keyArrowUp);
  Input_Backward                .Assign(keyS, keyArrowDown);
  Input_LeftRotate              .Assign(keyArrowLeft, keyA);
  Input_RightRotate             .Assign(keyArrowRight, keyD);
  Input_LeftStrafe              .Assign(keyNone);
  Input_RightStrafe             .Assign(keyNone);
  Input_CameraCloser            .Assign(keyNone);
  Input_CameraFurther           .Assign(keyNone);
  Input_Crouch                  .Assign(keyCtrl);
  Input_Run                     .Assign(keyShift);
  Input_Jump                    .Assign(keySpace);

  Input_Forward                .SetSubComponent(true);
  Input_Backward               .SetSubComponent(true);
  Input_LeftRotate             .SetSubComponent(true);
  Input_RightRotate            .SetSubComponent(true);
  Input_LeftStrafe             .SetSubComponent(true);
  Input_RightStrafe            .SetSubComponent(true);
  Input_CameraCloser           .SetSubComponent(true);
  Input_CameraFurther          .SetSubComponent(true);
  Input_Crouch                 .SetSubComponent(true);
  Input_Run                    .SetSubComponent(true);
  Input_Jump                   .SetSubComponent(true);

  Input_Forward                .Name := 'Input_Forward';
  Input_Backward               .Name := 'Input_Backward';
  Input_LeftRotate             .Name := 'Input_LeftRotate';
  Input_RightRotate            .Name := 'Input_RightRotate';
  Input_LeftStrafe             .Name := 'Input_LeftStrafe';
  Input_RightStrafe            .Name := 'Input_RightStrafe';
  Input_CameraCloser           .Name := 'Input_CameraCloser';
  Input_CameraFurther          .Name := 'Input_CameraFurther';
  Input_Crouch                 .Name := 'Input_Crouch';
  Input_Run                    .Name := 'Input_Run';
  Input_Jump                   .Name := 'Input_Jump';

  {$define read_implementation_constructor}
  {$I auto_generated_persistent_vectors/tcastlethirdpersonnavigation_persistent_vectors.inc}
  {$undef read_implementation_constructor}

  // override vector change method, to call Init in design mode when this changes
  AvatarTargetPersistent.InternalSetValue := {$ifdef FPC}@{$endif}MySetAvatarTargetForPersistent;

  FMovementType := mtVelocity;
  //FMovementType := mtForce;
  FWasJumpInput := false;
  FAirMovementControl := DefaultAirMovementControl;
  FAirRotationControl := DefaultAirRotationControl;
end;

procedure TCastleThirdPersonNavigation.MySetAvatarTargetForPersistent(const AValue: TVector3);
begin
  SetAvatarTargetForPersistent(AValue);
  if CastleDesignMode then
    Init;
end;

destructor TCastleThirdPersonNavigation.Destroy;
begin
  { set to nil by SetXxx, to detach free notification }
  Avatar := nil;
  AvatarHierarchy := nil;

  {$define read_implementation_destructor}
  {$I auto_generated_persistent_vectors/tcastlethirdpersonnavigation_persistent_vectors.inc}
  {$undef read_implementation_destructor}
  inherited;
end;

function TCastleThirdPersonNavigation.RealAvatarHierarchy: TCastleTransform;
begin
  if AvatarHierarchy <> nil then
    Result := AvatarHierarchy
  else
    Result := Avatar;
end;

procedure TCastleThirdPersonNavigation.SetAvatar(const Value: TCastleScene);
begin
  if FAvatar <> Value then
  begin
    FAvatar := Value;
    FAvatarFreeObserver.Observed := Value;
    SetAnimationWarningsDone := 0;

    (* This code is not needed at all, our Update will call Init
       if RealAvatarHierarchy remains non-nil.

    { When we change Value to nil because object is being destroyed,
      we cannot call Init.

      Reason: In case FAvatarHierarchy (the other TCastleTransform
      reference in TCastleThirdPersonNavigation)
      remains non-nil, Init would call FixCameraForCollisions,
      which accesses World, and the World still contains the TCastleTransform
      that is right now in csDestroying state and has no octree.

      Testcase: third_person_navigation, assign non-nil (different) values to both
      Avatar and AvatarHierarchy, then free the referenced component
      (either Avatar or AvatarHierarchy). Without check "(Value <> nil)"
      there would be a crash.

      This also secures us in case Avatar and AvatarHierarchy refer to
      the same object. In this case, we have a dangling pointer,
      before *both* free notifications run. }
    if (Value <> nil) and CastleDesignMode then
      Init;
    *)
  end;
end;

procedure TCastleThirdPersonNavigation.SetAvatarHierarchy(const Value: TCastleTransform);
begin
  if FAvatarHierarchy <> Value then
  begin
    FAvatarHierarchy := Value;
    FAvatarHierarchyFreeObserver.Observed := Value;

    (* This code is not needed at all, our Update will call Init
       if RealAvatarHierarchy remains non-nil.

    { Same comments as in SetAvatar about the "(Value <> nil)" condition.
      It is necessary.

      Note about one edge-case:

      If you assign both Avatar and AvatarHierarchy
      to some different non-nil values, and then set AvatarHierarchy to nil,
      we should call Init to change camera (because RealAvatarHierarchy changed,
      it now points to Avatar). But we don't, because of this "(Value <> nil)"
      condition.

      However, no problem - it will be called by Update anyway,
      because RealAvatarHierarchy <> nil.
      So user will not notice the problem. }
    if (Value <> nil) and CastleDesignMode then
      Init;
    *)
  end;
end;

function TCastleThirdPersonNavigation.CameraPositionInitial(const A: TCastleTransform): TVector3;
var
  TargetWorldPos: TVector3;
begin
  Result := CameraPositionInitial(A, TargetWorldPos); // ignore resulting TargetWorldPos
end;

function TCastleThirdPersonNavigation.ToGravityPlane(const V: TVector3; const GravUp: TVector3): TVector3;
begin
  Result := V;
  if not VectorsParallel(Result, GravUp) then
    MakeVectorsOrthoOnTheirPlane(Result, GravUp);
end;

function TCastleThirdPersonNavigation.CameraPositionInitial(const A: TCastleTransform; out TargetWorldPos: TVector3): TVector3;
var
  GravUp: TVector3;
  TargetWorldDir: TVector3;
  HorizontalShiftFromTarget: Single;
begin
  TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);
  TargetWorldDir := A.WorldTransform.MultDirection(TCastleTransform.DefaultDirection[A.Orientation]);

  { InitialHeightAboveTarget, HorizontalShiftFromTarget, DistanceToAvatarTarget
    create a right triangle, so
    InitialHeightAboveTarget^2 + HorizontalShiftFromTarget^2 = DistanceToAvatarTarget^2
  }
  HorizontalShiftFromTarget := Sqrt(Sqr(DistanceToAvatarTarget) - Sqr(InitialHeightAboveTarget));
  GravUp := Camera.GravityUp;

  Result := TargetWorldPos
    + GravUp * InitialHeightAboveTarget
    - ToGravityPlane(TargetWorldDir, GravUp) * HorizontalShiftFromTarget;
end;

procedure TCastleThirdPersonNavigation.FixCameraForCollisions(
  var CameraPos: TVector3; const CameraDir: TVector3);
var
  MaxDistance: Single;
  A: TCastleTransform;
  TargetWorldPos: TVector3;
begin
  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);
    MaxDistance := CameraMaxDistanceToTarget(A, TargetWorldPos, CameraDir);
    if PointsDistanceSqr(CameraPos, TargetWorldPos) > Sqr(MaxDistance) then
      // Note that CameraDir is not necessarily normalized now
      CameraPos := TargetWorldPos - CameraDir.AdjustToLength(MaxDistance);
  end;
end;

function TCastleThirdPersonNavigation.CameraMaxDistanceToTarget(
  const A: TCastleTransform; const CameraLookPos: TVector3;
  const CameraDir: TVector3): Single;
var
  CollisionDistance: Single;
  SavedAPickable: Boolean;
begin
  Result := MaxSingle;
  SavedAPickable := A.Pickable;
  A.Pickable := false;
  try
    if A.World.WorldRayCast(CameraLookPos, -CameraDir, CollisionDistance) <> nil then
    begin
      { Use MinDistanceToAvatarTarget to secure in case wall is closer than Radius
        (CollisionDistance - Radius negative)
        or just to close to head.
        Then use MinDistanceToAvatarTarget. }
      Result := Max(MinDistanceToAvatarTarget, CollisionDistance - Radius);
    end;
  finally A.Pickable := SavedAPickable end;
end;

procedure TCastleThirdPersonNavigation.Init;
var
  GravUp: TVector3;
  A: TCastleTransform;
  CameraPos, CameraDir, CameraUp, TargetWorldPos: TVector3;
begin
  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    if CameraFollows then
    begin
      GravUp := Camera.GravityUp;

      CameraPos := CameraPositionInitial(A, TargetWorldPos);
      CameraDir := TargetWorldPos - CameraPos;
      CameraUp := GravUp; // will be adjusted to be orthogonal to Dir by SetView
      FixCameraForCollisions(CameraPos, CameraDir);
      Camera.SetView(CameraPos, CameraDir, CameraUp);
    end;

    if Avatar <> nil then
    begin
      SetAnimation([AnimationIdle]);
      Avatar.ForceInitialAnimationPose;
    end;
  end;
end;

procedure TCastleThirdPersonNavigation.ProcessMouseLookDelta(const Delta: TVector2);
var
  ToCamera, GravUp: TVector3;
  A: TCastleTransform;

  { Change ToCamera by applying DeltaY from mouse look. }
  procedure ProcessVertical(DeltaY: Single);
  const
    { Do not allow to look exactly up or exactly down,
      as then further vertical moves would be undefined,
      so you would not be able to "get out" of such rotation. }
    MinimalAngleFromZenith = 0.1;
  var
    Side: TVector3;
    AngleToUp, AngleToDown, MaxChange: Single;
  begin
    Side := -TVector3.CrossProduct(ToCamera, GravUp);
    if DeltaY > 0 then
    begin
      AngleToDown := AngleRadBetweenVectors(ToCamera, -GravUp);
      MaxChange := Max(0, AngleToDown - MinimalAngleFromZenith);
      if DeltaY > MaxChange then
        DeltaY := MaxChange;
    end else
    begin
      AngleToUp := AngleRadBetweenVectors(ToCamera, GravUp);
      MaxChange := Max(0, AngleToUp - MinimalAngleFromZenith);
      if DeltaY < -MaxChange then
        DeltaY := -MaxChange;
    end;
    ToCamera := RotatePointAroundAxisRad(DeltaY, ToCamera, Side);
  end;

  procedure ProcessHorizontal(const DeltaX: Single);
  begin
    ToCamera := RotatePointAroundAxisRad(-DeltaX, ToCamera, GravUp);
  end;

var
  CameraPos, CameraDir, CameraUp, TargetWorldPos, LookPos: TVector3;
begin
  inherited;
  if not CameraFollows then
   Exit;

  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    Camera.GetWorldView(CameraPos, CameraDir, CameraUp);
    GravUp := Camera.GravityUp;

    TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);
    // Since camera may update with some delay, we may not look exactly at TargetWorldPos if avatar moved
    LookPos := PointOnLineClosestToPoint(CameraPos, CameraDir, TargetWorldPos);

    ToCamera := CameraPos - LookPos;

    ProcessVertical(Delta[1]);
    ProcessHorizontal(Delta[0]);

    CameraPos := LookPos + ToCamera;
    CameraDir := LookPos - CameraPos;
    CameraUp := GravUp; // will be adjusted to be orthogonal to Dir by SetWorldView
    if ImmediatelyFixBlockedCamera then
      FixCameraForCollisions(CameraPos, CameraDir);
    Camera.SetWorldView(CameraPos, CameraDir, CameraUp);
  end;
end;

function TCastleThirdPersonNavigation.Press(const Event: TInputPressRelease): Boolean;
var
  A: TCastleTransform;

  procedure CameraDistanceChange(DistanceChange: Single);
  begin
    DistanceChange := DistanceChange * CameraDistanceChangeSpeed;
    DistanceToAvatarTarget := Clamped(DistanceToAvatarTarget + DistanceChange,
      MinDistanceToAvatarTarget, MaxDistanceToAvatarTarget);

    { The actual change in Camera.Position, caused by changing DistanceToAvatarTarget,
      will be done smoothly in UpdateCamera. }
  end;

begin
  Result := inherited;
  if Result then Exit;

  A := RealAvatarHierarchy;
  if (A <> nil) and (InternalViewport <> nil) then
  begin
    if Input_CameraCloser.IsEvent(Event) then
    begin
      CameraDistanceChange(-1);
      Result := ExclusiveEvents;
    end;
    if Input_CameraFurther.IsEvent(Event) then
    begin
      CameraDistanceChange(1);
      Result := ExclusiveEvents;
    end;
  end;
end;

procedure TCastleThirdPersonNavigation.SetAnimation(const AnimationNames: array of String);
const
  MaxSetAnimationWarnings = 10;
var
  AnimName: String;
begin
  if Avatar <> nil then
  begin
    Assert(High(AnimationNames) >= 0); // at least one animation name provided
    for AnimName in AnimationNames do
      if Avatar.HasAnimation(AnimName) then
      begin
        if not CastleDesignMode then
          Avatar.AutoAnimation := AnimName; // do not change serialized AutoAnimation
        Exit;
      end;
    if SetAnimationWarningsDone < MaxSetAnimationWarnings then
    begin
      WritelnWarning('No useful animation exists on the avatar to show in the current state.' +NL +
        'Tried: %s.' +NL +
        'Add the animations to your model, or set the TCastleThirdPersonNavigation.AnimationXxx properties to point to the existing animations.', [
        GlueStrings(AnimationNames, ', ')
      ]);
      Inc(SetAnimationWarningsDone);
      if SetAnimationWarningsDone = MaxSetAnimationWarnings then
        WritelnWarning('Further warnings about avatar animations will not be done, to not flood the log, until you assign new Avatar value');
    end;
  end;
end;

procedure TCastleThirdPersonNavigation.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
var
  A: TCastleTransform;

  { Make camera follow the A.Translation.
    Following the character also makes sure that camera stays updated
    (keeps DistanceToAvatarTarget)
    when the avatar is being moved by other routines (e.g. because A.Gravity is working).

    Also avoid camera being blocked by some wall.
    This needs to be redone, in case some wall blocks us e.g. because of collisions.

    Does not follow the perfect location instantly,
    which makes a nice effect when character is moving fast.
    It's inportant to avoid sudden camera moves on sudden avatar moves,
    e.g. changing Y when going up/down stairs.
  }
  procedure UpdateCamera;
  var
    TargetWorldPos, CameraPos, CameraDir, CameraUp, CameraPosTarget, CameraDirToTarget: TVector3;
    MaxDistance: Single;
  begin
    if not CameraFollows then
      Exit;

    TargetWorldPos := A.WorldTransform.MultPoint(AvatarTarget);

    Camera.GetView(CameraPos, CameraDir, CameraUp);

    { We use CameraDirToTarget, not CameraDir, because (since we update with delay)
      camera may look at a slightly shifted point.
      But we still adjust camera position to look (without blockers) at avatar. }
    CameraDirToTarget := TargetWorldPos - CameraPos;

    { We need to check both CameraPosTarget and final CameraPos for collisions.
      But it would be wasteful to call FixCameraForCollisions 2 times,
      to calculate mostly the same.
      So we use one call to CameraMaxDistanceToTarget. }
    MaxDistance := CameraMaxDistanceToTarget(A, TargetWorldPos, CameraDirToTarget);

    { No need to use CameraDir.AdjustToLength(xxx) as we know CameraDir is normalized.
      Note that this is not entirely correct: we use distance we obtained with CameraDirToTarget,
      but our desired camera direction is CameraDir (i.e. unchanged from current camera direction). }
    CameraPosTarget := TargetWorldPos - CameraDir * Min(MaxDistance, DistanceToAvatarTarget);

    CameraPos := SmoothTowards(CameraPos, CameraPosTarget, SecondsPassed, CameraSpeed);
    if ImmediatelyFixBlockedCamera then
    begin
      if PointsDistanceSqr(CameraPos, TargetWorldPos) > Sqr(MaxDistance) then
        CameraPos := TargetWorldPos - CameraDir * MaxDistance;
    end;

    Camera.SetView(CameraPos, CameraDir, CameraUp);
  end;

  { Rotate avatar if needed by AimAvatar.
    Returns are we rotating now. }
  function UpdateAimAvatar: Boolean;
  const
    AngleEpsilon = 0.01;
  var
    TargetDir: TVector3;
    Angle: Single;
  begin
    Result := false;
    if AimAvatar = aaNone then Exit;

    // calculate TargetDir, in the same coordinate space as A.Direction
    TargetDir := Camera.Direction;
    if AimAvatar = aaHorizontal then
      TargetDir := ToGravityPlane(TargetDir, Camera.GravityUp);
    TargetDir := A.Parent.WorldToLocalDirection(TargetDir);

    Angle := AngleRadBetweenVectors(TargetDir, A.Direction);
    if Angle > AngleEpsilon then
    begin
      MinVar(Angle, AvatarRotationSpeed * SecondsPassed);
      A.Direction := RotatePointAroundAxisRad(Angle, A.Direction, -TVector3.CrossProduct(TargetDir, A.Direction));
      Result := true;
    end;
  end;

type
  TSpeedType = (stNormal, stCrouch, stRun);
var
  SpeedType: TSpeedType;
  Speed: Single;
  Moving, Rotating: Boolean;
  T: TVector3;
  Vel: TVector3;
  VLength: Single;
  DeltaSpeed: Single;
  DeltaAngular: Single;
  AvatarRigidBody: TCastleRigidBody;

  // physics velocity + force
  Collider: TCastleCollider;
  AvatarBoundingBox: TBox3D;
  AvatarHeight: Single;

  // velocity
  MaxHorizontalVelocityChange: Single;
  Acceleration: Single;
  HVelocity: TVector3;
  VVelocity: Single;
  MoveDirection: TVector3;
  Ground: TCastleTransform;
  IsOnGround: Boolean;
  DistanceToGround: Single;
  Jump: Single;
  RayOrigin: TVector3;

  // force
  DeltaForce: Single;
  Torque: Single;
begin
  inherited;

  A := RealAvatarHierarchy;
  if (A = nil) or (InternalViewport = nil) then
    Exit;

  if Input_Run.IsPressed(Container) then
  begin
    SpeedType := stRun;
    Speed := RunSpeed;
  end else
  if Input_Crouch.IsPressed(Container) then
  begin
    SpeedType := stCrouch;
    Speed := CrouchSpeed;
  end else
  begin
    SpeedType := stNormal;
    Speed := MoveSpeed;
  end;

  Moving := false;
  AvatarRigidBody := A.RigidBody;

  if AvatarRigidBody = nil then
  begin
    { Old movement algorithm }
    IsOnGround := true;
    T := TVector3.Zero;
    if Input_Forward.IsPressed(Container) then
    begin
      Moving := true;
      T := T + A.Direction * Speed * SecondsPassed;
    end;
    if Input_Backward.IsPressed(Container) then
    begin
      Moving := true;
      T := T - A.Direction * Speed * SecondsPassed;
    end;
    if Input_RightStrafe.IsPressed(Container) then
    begin
      Moving := true;
      T := T + TVector3.CrossProduct(A.Direction, A.Up) * Speed * SecondsPassed;
    end;
    if Input_LeftStrafe.IsPressed(Container) then
    begin
      Moving := true;
      T := T - TVector3.CrossProduct(A.Direction, A.Up) * Speed * SecondsPassed;
    end;

    if Input_RightRotate.IsPressed(Container) then
    begin
      Moving := true;
      A.Direction := RotatePointAroundAxisRad(-RotationSpeed * SecondsPassed, A.Direction, A.Up);
      { TODO: when AimAvatar, this is overridden by UpdateAimAvatar soon.
        In effect, keys AD don't work when AimAvatar <> aaNone. }
    end;
    if Input_LeftRotate.IsPressed(Container) then
    begin
      Moving := true;
      A.Direction := RotatePointAroundAxisRad(RotationSpeed * SecondsPassed, A.Direction, A.Up);
      { TODO: when AimAvatar, this is overridden by UpdateAimAvatar soon.
        In effect, keys AD don't work when AimAvatar <> aaNone. }
    end;

    if not T.IsPerfectlyZero then
      A.Move(T, false);

    Rotating := UpdateAimAvatar;
  end else
  begin
    { New movement algorithms based on physics. }
    case FMovementType of
      mtVelocity:
      begin
        { How fast should avatar change it's speed }
        Acceleration := Speed * 3 / 60;
        MaxHorizontalVelocityChange := Acceleration * 60;
        DeltaSpeed := 0;

        if AvatarRigidBody = nil then
        begin
          WritelnWarning('Avatar don''t have rigid body!');
          Exit;
        end;

        Collider := A.FindBehavior(TCastleCollider) as TCastleCollider;
        if Collider = nil then
        begin
          WritelnWarning('Avatar don''t have collider!');
          Exit;
        end;

        { Check player is on ground, we use avatar size multiplied by ten to try
          found ground. Distance is used to check we should set animation to fall
          or we are almost on ground so use default animation.

          We need add Collider.Translation because sometimes rigid body origin can be
          under the collider. And ray will be casted under the floor. }
        AvatarBoundingBox := A.BoundingBox;
        AvatarHeight := AvatarBoundingBox.SizeY;
        RayOrigin := A.Translation + Collider.Translation;

        Ground := AvatarRigidBody.PhysicsRayCast(
          RayOrigin,
          Vector3(0, -1, 0),
          AvatarHeight * 3,
          DistanceToGround
        );

        { Four more checks - player should slide down when player just
          on the edge, but sometimes it stay and center ray don't "see" that we are
          on ground }
        if Ground = nil then
          Ground := AvatarRigidBody.PhysicsRayCast(
            RayOrigin + Vector3(AvatarBoundingBox.SizeX * 0.49, 0, 0),
            Vector3(0, -1, 0),
            AvatarHeight * 3,
            DistanceToGround
          );

        if Ground = nil then
          Ground := AvatarRigidBody.PhysicsRayCast(
            RayOrigin + Vector3(-AvatarBoundingBox.SizeX * 0.49, 0, 0),
            Vector3(0, -1, 0),
            AvatarHeight * 3,
            DistanceToGround
          );

        if Ground = nil then
          Ground := AvatarRigidBody.PhysicsRayCast(
            RayOrigin + Vector3(0, 0, AvatarBoundingBox.SizeZ * 0.49),
            Vector3(0, -1, 0),
            AvatarHeight * 3,
            DistanceToGround
          );

        if Ground = nil then
          Ground := AvatarRigidBody.PhysicsRayCast(
            RayOrigin + Vector3(0, 0, -AvatarBoundingBox.SizeZ * 0.49),
            Vector3(0, -1, 0),
            AvatarHeight * 3,
            DistanceToGround
          );

        if (Ground <> nil) then
        begin
          { When collider has own translation we need substract it from distance
            becouse distance will be too big }
          DistanceToGround  := DistanceToGround - Collider.Translation.Y;

          { Sometimes rigid body center point can be under the collider so
            the distance can be negative }
          if DistanceToGround < 0 then
            DistanceToGround := 0;

          IsOnGround := DistanceToGround < AvatarHeight * 0.1;
        end else
        begin
          IsOnGround := false;
          DistanceToGround := -1; // For animation checking
        end;

        if Input_Forward.IsPressed(Container) then
        begin
          Moving := true;
          DeltaSpeed := MaxHorizontalVelocityChange * SecondsPassed * MovementControlFactor(IsOnGround);
          MoveDirection := A.Direction;
        end;
        if Input_Backward.IsPressed(Container) then
        begin
          Moving := true;
          DeltaSpeed := MaxHorizontalVelocityChange * SecondsPassed * MovementControlFactor(IsOnGround);
          MoveDirection := -A.Direction;
        end;
        if IsOnGround and Input_RightStrafe.IsPressed(Container) then
        begin
          Moving := true;
          DeltaSpeed := MaxHorizontalVelocityChange * SecondsPassed;
          MoveDirection := TVector3.CrossProduct(A.Direction, A.Up);
        end;
        if IsOnGround and Input_LeftStrafe.IsPressed(Container) then
        begin
          Moving := true;
          DeltaSpeed := MaxHorizontalVelocityChange * SecondsPassed * MovementControlFactor(IsOnGround);
          MoveDirection := -TVector3.CrossProduct(A.Direction, A.Up);
        end;

        Jump := 0;
        if Input_Jump.IsPressed(Container) and (not FWasJumpInput) and IsOnGround then
        begin
          //if  and (not FWasJumpInput) and IsOnGround
          FWasJumpInput := true;
          Moving := false;
          Jump := JumpSpeed;
        end else
          FWasJumpInput := false;

        DeltaAngular := 0;
        if Input_RightRotate.IsPressed(Container) then
        begin
          Moving := true;
          DeltaAngular := -RotationSpeed * 60 * SecondsPassed * RotationControlFactor(IsOnGround);
        end;
        if Input_LeftRotate.IsPressed(Container) then
        begin
          Moving := true;
          DeltaAngular := RotationSpeed * 60 * SecondsPassed * RotationControlFactor(IsOnGround);
        end;

        // jumping
        if not IsZero(Jump) then
        begin
          Vel := AvatarRigidBody.LinearVelocity;
          Vel.Y := Jump;
          AvatarRigidBody.LinearVelocity := Vel;
        end else
        // moving
        if not IsZero(DeltaSpeed) then
        begin
          Vel := AvatarRigidBody.LinearVelocity;
          if IsOnGround then
          begin
            { On ground we simply change direction to current one that's
              helps do things like strafe or fast change direction from
              forward to backward }
            HVelocity := Vel;
            HVelocity.Y := 0;
            VVelocity := Vel.Y;
            // maybe use LengthSqrt?
            VLength := HVelocity.Length;
            VLength := VLength + DeltaSpeed;
            if VLength > Speed then
                VLength := Speed;
            Vel := MoveDirection * VLength;

            if IsZero(Jump) then
              Vel.Y := VVelocity
            else
              Vel.Y := Jump;
          end else
          begin
            { In air we can't simply change movement direction, we will just
              modify current one a little based on FAirMovementControl factor.
              Notice that by default FAirMovementControl = 0 so no change
              will be made. }

            Vel := Vel + MoveDirection * DeltaSpeed;

            { Here we only check speed is not faster than max speed }
            HVelocity := Vel;
            HVelocity.Y := 0;
            VVelocity := Vel.Y;
            VLength := HVelocity.Length;
            { Check max speed }
            if VLength > Speed then
            begin
                VLength := Speed;
                Vel.Y := 0;
                Vel := Vel.Normalize * VLength;

                { Add gravity here }
                Vel.Y := VVelocity;
            end;
          end;

          AvatarRigidBody.LinearVelocity := Vel;
        end else
        if IsOnGround then
        begin
          // slowing down the avatar only on ground
          Vel := AvatarRigidBody.LinearVelocity;
          Vel.X := 0;
          Vel.Z := 0;
          AvatarRigidBody.LinearVelocity := Vel;
        end;

        // rotation
        if not IsZero(DeltaAngular) then
        begin
          AvatarRigidBody.AngularVelocity := Vector3(0, 1, 0) * DeltaAngular;
          Rotating := true;
        end
        else
        begin
          AvatarRigidBody.AngularVelocity := Vector3(0, 0, 0);
          Rotating := false;
        end;

      end;
      mtForce:
      begin
        // TODO: Not finished.

        Collider := A.FindBehavior(TCastleCollider) as TCastleCollider;
        if Collider = nil then
          Exit;

        DeltaForce := 0;

        if Input_Forward.IsPressed(Container) then
        begin
          Moving := true;
          DeltaForce := Speed * 2 * Collider.Mass * SecondsPassed * 60 {* MovementControlFactor(IsOnGround)};
          WritelnLog('DeltaForce ' + FloatToStr(DeltaForce));
          //MoveDirection := A.WorldToLocal(A.Direction); // for AddCenterForce
          MoveDirection := A.Direction;
        end;

        if Input_Backward.IsPressed(Container) then
        begin
          Moving := true;
          DeltaForce := Speed * 2 * Collider.Mass * SecondsPassed * 60 {* MovementControlFactor(IsOnGround)};
          WritelnLog('DeltaForce ' + FloatToStr(DeltaForce));
          //MoveDirection := A.WorldToLocal(-A.Direction); // for AddCenterForce
          MoveDirection := -A.Direction;
        end;

        Torque := 0;
        if Input_RightRotate.IsPressed(Container) then
        begin
          Moving := true;
          Torque := -RotationSpeed * 60 * SecondsPassed {* RotationControlFactor(IsOnGround)};
        end;
        if Input_LeftRotate.IsPressed(Container) then
        begin
          Moving := true;
          Torque := RotationSpeed * 60 * SecondsPassed {* RotationControlFactor(IsOnGround)};
        end;

        if not IsZero(Torque) then
        begin
          AvatarRigidBody.AddTorque(A.Up * Torque);
          Rotating := true;
        end else
        if not AvatarRigidBody.AngularVelocity.IsZero(0.1) then
        begin
          Rotating := true;
          { TODO: In case of space ship this is not OK.}
        end else
        begin
          //AvatarRigidBody.AngularVelocity := Vector3(0, 0, 0);
          Rotating := false;
        end;


        if Moving then
        begin
          AvatarRigidBody.AddForce(MoveDirection * DeltaForce, A.Translation);
          //AvatarRigidBody.AddCenterForce(MoveDirection * DeltaForce);
          //AvatarRigidBody.ApplyImpulse(MoveDirection * DeltaForce, A.Translation);
          //AvatarRigidBody.ApplyImpulse(MoveDirection * DeltaForce, Collider.Translation);
        end;
      end;
    end;
  end;

  { TODO: In case we use AimAvatar and you move mouse very slowly for short amounts,
    we may switch very quickly between AnimationIdle and AnimationRotate.
    This makes somewhat bad look in third_person_navigation, and though it uses
    DefaultAnimationTransition <> 0.
    Should we protect from it here, to introduce minimal time to change
    animation between rotating/non-rotating variant? }

  // change Avatar.AutoAnimation
  { Checking is avatar on ground works only with new movement algorithms }
  if not IsOnGround then
  begin
    case FMovementType of
      mtVelocity:
        if AvatarRigidBody.LinearVelocity.Y > 0.1 then
          SetAnimation([AnimationJump, AnimationIdle])
        else
          { When avatar fall we change animation to fall only when distance
            to ground is smaller than 1/4 of avatar height. That fix changing
            animation from walk to fall on small steps like in stairs.

            DistanceToGround < 0 means that we are in air and ground
            was not found. }
          if (DistanceToGround < 0) or (DistanceToGround > A.LocalBoundingBox.SizeY * 0.25) then
            SetAnimation([AnimationFall, AnimationIdle]);
      mtForce:
        ;
    end;
  end else
  if Moving then
  begin
    case SpeedType of
      stNormal: SetAnimation([AnimationWalk, AnimationIdle]);
      stRun   : SetAnimation([AnimationRun, AnimationIdle]);
      stCrouch: SetAnimation([AnimationCrouch, AnimationCrouchIdle, AnimationIdle]);
      // else raise EInternalError.Create('Unhandled SpeedType'); // new FPC will warn in case of unhandled "else"
    end;
  end else
  begin
    if SpeedType = stCrouch then
    begin
      if Rotating then
        SetAnimation([AnimationCrouchRotate, AnimationCrouch, AnimationCrouchIdle, AnimationIdle])
      else
        SetAnimation([AnimationCrouchIdle, AnimationCrouch, AnimationIdle]);
    end else
    begin
      { Note that stRun behaves the same as ssNormal when Moving = false.
        This just means user holds Shift (Input_Run) but not actually moving by AWSD. }
      if Rotating then
        SetAnimation([AnimationRotate, AnimationWalk, AnimationIdle])
      else
        SetAnimation([AnimationIdle]);
    end;
  end;

  if CastleDesignMode then
    { In design mode, update immediately both position and direction of the camera.
      This reflects that Init should be done at the beginning of actual game. }
    Init
  else
    UpdateCamera;

end;

{ Since String values cannot have default properties,
  we use "stored" methods to avoid storing default value. }

function TCastleThirdPersonNavigation.AnimationIdleStored: Boolean;
begin
  Result := FAnimationIdle <> DefaultAnimationIdle;
end;

function TCastleThirdPersonNavigation.AnimationRotateStored: Boolean;
begin
  Result := FAnimationRotate <> DefaultAnimationRotate;
end;

function TCastleThirdPersonNavigation.AnimationWalkStored: Boolean;
begin
  Result := FAnimationWalk <> DefaultAnimationWalk;
end;

function TCastleThirdPersonNavigation.AnimationRunStored: Boolean;
begin
  Result := FAnimationRun <> DefaultAnimationRun;
end;

function TCastleThirdPersonNavigation.AnimationCrouchStored: Boolean;
begin
  Result := FAnimationCrouch <> DefaultAnimationCrouch;
end;

function TCastleThirdPersonNavigation.AnimationCrouchIdleStored: Boolean;
begin
  Result := FAnimationCrouchIdle <> DefaultAnimationCrouchIdle;
end;

function TCastleThirdPersonNavigation.AnimationCrouchRotateStored: Boolean;
begin
  Result := FAnimationCrouchRotate <> DefaultAnimationCrouchRotate;
end;

function TCastleThirdPersonNavigation.AnimationJumpStored: Boolean;
begin
  Result := FAnimationJump <> DefaultAnimationJump;
end;

function TCastleThirdPersonNavigation.AnimationFallStored: Boolean;
begin
  Result := FAnimationFall <> DefaultAnimationFall;
end;

procedure TCastleThirdPersonNavigation.SetInitialHeightAboveTarget(const Value: Single);
begin
  if FInitialHeightAboveTarget <> Value then
  begin
    FInitialHeightAboveTarget := Value;
    if CastleDesignMode then Init;
  end;
end;

procedure TCastleThirdPersonNavigation.SetDistanceToAvatarTarget(const Value: Single);
begin
  if FDistanceToAvatarTarget <> Value then
  begin
    FDistanceToAvatarTarget := Value;
    if CastleDesignMode then Init;
  end;
end;

procedure TCastleThirdPersonNavigation.SetCameraFollows(const Value: Boolean);
begin
  if FCameraFollows <> Value then
  begin
    FCameraFollows := Value;
    if CastleDesignMode then Init;
  end;
end;

function TCastleThirdPersonNavigation.PropertySections(const PropertyName: String): TPropertySections;
begin
  if (PropertyName = 'CameraFollows') or
     (PropertyName = 'AvatarTarget') or
     (PropertyName = 'Avatar') or
     (PropertyName = 'AvatarHierarchy') or
     (PropertyName = 'Radius') or
     (PropertyName = 'AimAvatar') or
     (PropertyName = 'MoveSpeed') or
     (PropertyName = 'CrouchSpeed') or
     (PropertyName = 'RunSpeed') or
     (PropertyName = 'JumpSpeed') or
     (PropertyName = 'RotationSpeed') or
     (PropertyName = 'AirMovementControl') or
     (PropertyName = 'AirRotationControl') or
     (PropertyName = 'AnimationIdle') or
     (PropertyName = 'AnimationWalk') or
     (PropertyName = 'AnimationRun') or
     (PropertyName = 'AnimationJump') or
     (PropertyName = 'AnimationRotate') or
     (PropertyName = 'AnimationCrouch') or
     (PropertyName = 'AnimationCrouchIdle') or
     (PropertyName = 'AnimationCrouchRotate') or
     (PropertyName = 'AnimationFall') or
     (PropertyName = 'InitialHeightAboveTarget') or
     (PropertyName = 'DistanceToAvatarTarget') then
    Result := [psBasic]
  else
    Result := inherited PropertySections(PropertyName);
end;

procedure TCastleThirdPersonNavigation.AvatarFreeNotification(
  const Sender: TFreeNotificationObserver);
begin
  Avatar := nil;
end;

procedure TCastleThirdPersonNavigation.AvatarHierarchyFreeNotification(
  const Sender: TFreeNotificationObserver);
begin
  AvatarHierarchy := nil;
end;

function TCastleThirdPersonNavigation.MovementControlFactor(
  const AvatarOnGround: Boolean): Single;
begin
  if AvatarOnGround then
    Exit(1.0)
  else
    Result := FAirMovementControl;
end;

function TCastleThirdPersonNavigation.RotationControlFactor(
  const AvatarOnGround: Boolean): Single;
begin
  if AvatarOnGround then
    Exit(1.0)
  else
    Result := FAirRotationControl;
end;

{$define read_implementation_methods}
{$I auto_generated_persistent_vectors/tcastlethirdpersonnavigation_persistent_vectors.inc}
{$undef read_implementation_methods}

initialization
  RegisterSerializableComponent(TCastleThirdPersonNavigation, 'Navigation/Third-Person');
end.
