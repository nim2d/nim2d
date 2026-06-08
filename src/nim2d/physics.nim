## 2D rigid-body physics on Box2D.
##
## Build a `World` with some gravity, add static, dynamic or kinematic bodies,
## give them box or circle shapes, then call `update` each frame to step the
## simulation. Read a body's `position` and `angle` to draw it.
##
## Box2D is happiest in small units like meters, so pick a scale (say 50 pixels
## per unit), simulate in those units, and multiply when you draw, rather than
## feeding pixel-sized numbers to the solver.
##
## This needs Box2D installed (brew install box2d) and is imported on its own
## with `import nim2d/physics`, since not every program wants the dependency.

import backend/box2d

type
  BodyType* = enum
    btStatic, btDynamic, btKinematic

  World* = ref object
    id: b2WorldId

  Body* = object
    id: b2BodyId

proc newWorld*(gravityX = 0.0, gravityY = 9.81): World =
  ## A physics world with the given gravity. Positive y points down, matching the
  ## screen, so the default pulls bodies downward.
  var def = b2DefaultWorldDef()
  def.gravity = b2Vec2(x: gravityX.cfloat, y: gravityY.cfloat)
  World(id: b2CreateWorld(addr def))

proc destroy*(w: World) =
  ## Free the world and everything in it.
  b2DestroyWorld(w.id)

proc update*(w: World, dt: float, subSteps = 4) =
  ## Advance the simulation by `dt` seconds. A steady `dt` and a few sub-steps
  ## give the most stable result.
  b2World_Step(w.id, dt.cfloat, subSteps.cint)

proc newBody*(w: World, x, y: float, kind = btDynamic): Body =
  ## Add a body at (x, y). Dynamic bodies move and collide, static ones never
  ## move (floors and walls), kinematic ones move only by the velocity you set.
  var def = b2DefaultBodyDef()
  def.`type` = case kind
    of btStatic: b2_staticBody
    of btDynamic: b2_dynamicBody
    of btKinematic: b2_kinematicBody
  def.position = b2Vec2(x: x.cfloat, y: y.cfloat)
  Body(id: b2CreateBody(w.id, addr def))

proc addBox*(b: Body, halfWidth, halfHeight: float,
             density = 1.0, friction = 0.6, restitution = 0.0) =
  ## Give the body a rectangular shape, sized by its half extents.
  var sd = b2DefaultShapeDef()
  sd.density = density.cfloat
  sd.material.friction = friction.cfloat
  sd.material.restitution = restitution.cfloat
  var poly = b2MakeBox(halfWidth.cfloat, halfHeight.cfloat)
  discard b2CreatePolygonShape(b.id, addr sd, addr poly)

proc addCircle*(b: Body, radius: float,
                density = 1.0, friction = 0.6, restitution = 0.0) =
  ## Give the body a circular shape.
  var sd = b2DefaultShapeDef()
  sd.density = density.cfloat
  sd.material.friction = friction.cfloat
  sd.material.restitution = restitution.cfloat
  var circle = b2Circle(center: b2Vec2(x: 0, y: 0), radius: radius.cfloat)
  discard b2CreateCircleShape(b.id, addr sd, addr circle)

proc position*(b: Body): tuple[x, y: float] =
  ## The body's center position.
  let p = b2Body_GetPosition(b.id)
  (p.x.float, p.y.float)

proc angle*(b: Body): float =
  ## The body's rotation in radians.
  b2Rot_GetAngle(b2Body_GetRotation(b.id)).float

proc velocity*(b: Body): tuple[x, y: float] =
  ## The body's linear velocity.
  let v = b2Body_GetLinearVelocity(b.id)
  (v.x.float, v.y.float)

proc setVelocity*(b: Body, x, y: float) =
  ## Set the body's linear velocity.
  b2Body_SetLinearVelocity(b.id, b2Vec2(x: x.cfloat, y: y.cfloat))

proc applyForce*(b: Body, x, y: float) =
  ## Apply a steady force at the body's center.
  b2Body_ApplyForceToCenter(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), true)

proc applyImpulse*(b: Body, x, y: float) =
  ## Apply an instantaneous impulse at the body's center, for a kick or a jump.
  b2Body_ApplyLinearImpulseToCenter(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), true)

proc setPosition*(b: Body, x, y: float, angle = 0.0) =
  ## Teleport the body to a position and angle.
  b2Body_SetTransform(b.id, b2Vec2(x: x.cfloat, y: y.cfloat), b2MakeRot(angle.cfloat))

proc destroy*(b: Body) =
  ## Remove the body from its world.
  b2DestroyBody(b.id)
