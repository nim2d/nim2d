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
