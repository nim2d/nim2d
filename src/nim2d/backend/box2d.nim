## Minimal Box2D 3.x binding for the physics module.
##
## Box2D is a separate dependency (brew install box2d), so only programs that use
## the physics module pull this in. The struct layouts come straight from the C
## header through importc, so this only names the fields the wrapper touches; the
## C compiler fills in the rest and gets the sizes right.

{.passL: "-lbox2d".}

const hdr = "box2d/box2d.h"

type
  b2Vec2* {.importc: "b2Vec2", header: hdr, bycopy.} = object
    x*, y*: cfloat
  b2Rot* {.importc: "b2Rot", header: hdr, bycopy.} = object
    c*, s*: cfloat
  b2WorldId* {.importc: "b2WorldId", header: hdr, bycopy.} = object
  b2BodyId* {.importc: "b2BodyId", header: hdr, bycopy.} = object
  b2ShapeId* {.importc: "b2ShapeId", header: hdr, bycopy.} = object
  b2Polygon* {.importc: "b2Polygon", header: hdr, bycopy.} = object
  b2Circle* {.importc: "b2Circle", header: hdr, bycopy.} = object
    center*: b2Vec2
    radius*: cfloat
  b2SurfaceMaterial* {.importc: "b2SurfaceMaterial", header: hdr, bycopy.} = object
    friction*: cfloat
    restitution*: cfloat
  b2WorldDef* {.importc: "b2WorldDef", header: hdr, bycopy.} = object
    gravity*: b2Vec2
  b2BodyDef* {.importc: "b2BodyDef", header: hdr, bycopy.} = object
    `type`*: cint            ## 0 static, 1 kinematic, 2 dynamic
    position*: b2Vec2
    fixedRotation*: bool
  b2ShapeDef* {.importc: "b2ShapeDef", header: hdr, bycopy.} = object
    density*: cfloat
    material*: b2SurfaceMaterial
    isSensor*: bool
    enableContactEvents*: bool

const
  b2_staticBody* = 0.cint
  b2_kinematicBody* = 1.cint
  b2_dynamicBody* = 2.cint

proc b2DefaultWorldDef*(): b2WorldDef {.importc: "b2DefaultWorldDef", header: hdr.}
proc b2CreateWorld*(def: ptr b2WorldDef): b2WorldId {.importc: "b2CreateWorld", header: hdr.}
proc b2DestroyWorld*(id: b2WorldId) {.importc: "b2DestroyWorld", header: hdr.}
proc b2World_Step*(id: b2WorldId, timeStep: cfloat, subStepCount: cint) {.importc: "b2World_Step", header: hdr.}

proc b2DefaultBodyDef*(): b2BodyDef {.importc: "b2DefaultBodyDef", header: hdr.}
proc b2CreateBody*(world: b2WorldId, def: ptr b2BodyDef): b2BodyId {.importc: "b2CreateBody", header: hdr.}
proc b2DestroyBody*(id: b2BodyId) {.importc: "b2DestroyBody", header: hdr.}
proc b2Body_GetPosition*(id: b2BodyId): b2Vec2 {.importc: "b2Body_GetPosition", header: hdr.}
proc b2Body_GetRotation*(id: b2BodyId): b2Rot {.importc: "b2Body_GetRotation", header: hdr.}
proc b2Body_GetLinearVelocity*(id: b2BodyId): b2Vec2 {.importc: "b2Body_GetLinearVelocity", header: hdr.}
proc b2Body_SetLinearVelocity*(id: b2BodyId, v: b2Vec2) {.importc: "b2Body_SetLinearVelocity", header: hdr.}
proc b2Body_ApplyForceToCenter*(id: b2BodyId, force: b2Vec2, wake: bool) {.importc: "b2Body_ApplyForceToCenter", header: hdr.}
proc b2Body_ApplyLinearImpulseToCenter*(id: b2BodyId, impulse: b2Vec2, wake: bool) {.importc: "b2Body_ApplyLinearImpulseToCenter", header: hdr.}
proc b2Body_SetTransform*(id: b2BodyId, position: b2Vec2, rotation: b2Rot) {.importc: "b2Body_SetTransform", header: hdr.}

proc b2Rot_GetAngle*(q: b2Rot): cfloat {.importc: "b2Rot_GetAngle", header: hdr.}
proc b2MakeRot*(angle: cfloat): b2Rot {.importc: "b2MakeRot", header: hdr.}

proc b2DefaultShapeDef*(): b2ShapeDef {.importc: "b2DefaultShapeDef", header: hdr.}
proc b2MakeBox*(halfWidth, halfHeight: cfloat): b2Polygon {.importc: "b2MakeBox", header: hdr.}
proc b2CreatePolygonShape*(body: b2BodyId, def: ptr b2ShapeDef, polygon: ptr b2Polygon): b2ShapeId {.importc: "b2CreatePolygonShape", header: hdr.}
proc b2CreateCircleShape*(body: b2BodyId, def: ptr b2ShapeDef, circle: ptr b2Circle): b2ShapeId {.importc: "b2CreateCircleShape", header: hdr.}

# --- user data, shape-to-body, local points --------------------------------
proc b2Body_SetUserData*(id: b2BodyId, p: pointer) {.importc: "b2Body_SetUserData", header: hdr.}
proc b2Body_GetUserData*(id: b2BodyId): pointer {.importc: "b2Body_GetUserData", header: hdr.}
proc b2Shape_GetBody*(id: b2ShapeId): b2BodyId {.importc: "b2Shape_GetBody", header: hdr.}
proc b2Body_GetLocalPoint*(id: b2BodyId, worldPoint: b2Vec2): b2Vec2 {.importc: "b2Body_GetLocalPoint", header: hdr.}

# --- raycasts and overlap queries ------------------------------------------
type
  b2QueryFilter* {.importc: "b2QueryFilter", header: hdr, bycopy.} = object
  b2TreeStats* {.importc: "b2TreeStats", header: hdr, bycopy.} = object
  b2AABB* {.importc: "b2AABB", header: hdr, bycopy.} = object
    lowerBound*, upperBound*: b2Vec2
  b2RayResult* {.importc: "b2RayResult", header: hdr, bycopy.} = object
    shapeId*: b2ShapeId
    point*: b2Vec2
    normal*: b2Vec2
    fraction*: cfloat
    hit*: bool
  b2OverlapFcn* = proc(shapeId: b2ShapeId, ctx: pointer): bool {.cdecl.}

proc b2DefaultQueryFilter*(): b2QueryFilter {.importc: "b2DefaultQueryFilter", header: hdr.}
proc b2World_CastRayClosest*(world: b2WorldId, origin, translation: b2Vec2,
                             filter: b2QueryFilter): b2RayResult {.importc: "b2World_CastRayClosest", header: hdr.}
proc b2World_OverlapAABB*(world: b2WorldId, aabb: b2AABB, filter: b2QueryFilter,
                          fcn: b2OverlapFcn, ctx: pointer): b2TreeStats {.importc: "b2World_OverlapAABB", header: hdr.}

# --- contact events (polled after a step) ----------------------------------
type
  b2ContactBeginTouchEvent* {.importc: "b2ContactBeginTouchEvent", header: hdr, bycopy.} = object
    shapeIdA*, shapeIdB*: b2ShapeId
  b2ContactEndTouchEvent* {.importc: "b2ContactEndTouchEvent", header: hdr, bycopy.} = object
    shapeIdA*, shapeIdB*: b2ShapeId
  b2ContactEvents* {.importc: "b2ContactEvents", header: hdr, bycopy.} = object
    beginEvents*: ptr b2ContactBeginTouchEvent
    endEvents*: ptr b2ContactEndTouchEvent
    beginCount*: cint
    endCount*: cint

proc b2World_GetContactEvents*(world: b2WorldId): b2ContactEvents {.importc: "b2World_GetContactEvents", header: hdr.}

# --- joints -----------------------------------------------------------------
type
  b2JointId* {.importc: "b2JointId", header: hdr, bycopy.} = object
  b2RevoluteJointDef* {.importc: "b2RevoluteJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    localAnchorA*, localAnchorB*: b2Vec2
    enableLimit*: bool
    lowerAngle*, upperAngle*: cfloat
    enableMotor*: bool
    motorSpeed*, maxMotorTorque*: cfloat
  b2DistanceJointDef* {.importc: "b2DistanceJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    localAnchorA*, localAnchorB*: b2Vec2
    length*: cfloat
    enableSpring*: bool
    hertz*, dampingRatio*: cfloat
    enableLimit*: bool
    minLength*, maxLength*: cfloat
  b2PrismaticJointDef* {.importc: "b2PrismaticJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    localAnchorA*, localAnchorB*, localAxisA*: b2Vec2
    enableLimit*: bool
    lowerTranslation*, upperTranslation*: cfloat
    enableMotor*: bool
    maxMotorForce*, motorSpeed*: cfloat
  b2WeldJointDef* {.importc: "b2WeldJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    localAnchorA*, localAnchorB*: b2Vec2
    linearHertz*, angularHertz*: cfloat
  b2WheelJointDef* {.importc: "b2WheelJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    localAnchorA*, localAnchorB*, localAxisA*: b2Vec2
    enableMotor*: bool
    motorSpeed*, maxMotorTorque*: cfloat
  b2MotorJointDef* {.importc: "b2MotorJointDef", header: hdr, bycopy.} = object
    bodyIdA*, bodyIdB*: b2BodyId
    linearOffset*: b2Vec2
    angularOffset*, maxForce*, maxTorque*: cfloat

proc b2DestroyJoint*(id: b2JointId) {.importc: "b2DestroyJoint", header: hdr.}

proc b2DefaultRevoluteJointDef*(): b2RevoluteJointDef {.importc: "b2DefaultRevoluteJointDef", header: hdr.}
proc b2CreateRevoluteJoint*(world: b2WorldId, def: ptr b2RevoluteJointDef): b2JointId {.importc: "b2CreateRevoluteJoint", header: hdr.}
proc b2RevoluteJoint_GetAngle*(id: b2JointId): cfloat {.importc: "b2RevoluteJoint_GetAngle", header: hdr.}
proc b2RevoluteJoint_EnableMotor*(id: b2JointId, enable: bool) {.importc: "b2RevoluteJoint_EnableMotor", header: hdr.}
proc b2RevoluteJoint_SetMotorSpeed*(id: b2JointId, speed: cfloat) {.importc: "b2RevoluteJoint_SetMotorSpeed", header: hdr.}

proc b2DefaultDistanceJointDef*(): b2DistanceJointDef {.importc: "b2DefaultDistanceJointDef", header: hdr.}
proc b2CreateDistanceJoint*(world: b2WorldId, def: ptr b2DistanceJointDef): b2JointId {.importc: "b2CreateDistanceJoint", header: hdr.}

proc b2DefaultPrismaticJointDef*(): b2PrismaticJointDef {.importc: "b2DefaultPrismaticJointDef", header: hdr.}
proc b2CreatePrismaticJoint*(world: b2WorldId, def: ptr b2PrismaticJointDef): b2JointId {.importc: "b2CreatePrismaticJoint", header: hdr.}
proc b2PrismaticJoint_GetTranslation*(id: b2JointId): cfloat {.importc: "b2PrismaticJoint_GetTranslation", header: hdr.}
proc b2PrismaticJoint_EnableMotor*(id: b2JointId, enable: bool) {.importc: "b2PrismaticJoint_EnableMotor", header: hdr.}
proc b2PrismaticJoint_SetMotorSpeed*(id: b2JointId, speed: cfloat) {.importc: "b2PrismaticJoint_SetMotorSpeed", header: hdr.}

proc b2DefaultWeldJointDef*(): b2WeldJointDef {.importc: "b2DefaultWeldJointDef", header: hdr.}
proc b2CreateWeldJoint*(world: b2WorldId, def: ptr b2WeldJointDef): b2JointId {.importc: "b2CreateWeldJoint", header: hdr.}

proc b2DefaultWheelJointDef*(): b2WheelJointDef {.importc: "b2DefaultWheelJointDef", header: hdr.}
proc b2CreateWheelJoint*(world: b2WorldId, def: ptr b2WheelJointDef): b2JointId {.importc: "b2CreateWheelJoint", header: hdr.}

proc b2DefaultMotorJointDef*(): b2MotorJointDef {.importc: "b2DefaultMotorJointDef", header: hdr.}
proc b2CreateMotorJoint*(world: b2WorldId, def: ptr b2MotorJointDef): b2JointId {.importc: "b2CreateMotorJoint", header: hdr.}
