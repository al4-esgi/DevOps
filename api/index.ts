import { HttpLayerRouter, HttpServerResponse } from "@effect/platform"
import { NodeHttpServer } from "@effect/platform-node"
import { Effect, Layer } from "effect"
import { createServer } from "http"

const Routes = Layer.mergeAll(
  HttpLayerRouter.add("GET", "/", HttpServerResponse.text("Hello World!")),
  HttpLayerRouter.add("GET", "/users/:id", Effect.gen(function* () {
    const { params } = yield* HttpLayerRouter.RouteContext
    return yield* HttpServerResponse.json({ id: params.id, name: "John" })
  })),
  HttpLayerRouter.add("POST", "/users", HttpServerResponse.json({ created: true }, { status: 201 })),
)

HttpLayerRouter.serve(Routes).pipe(
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 })),
  Layer.launch,
  Effect.runFork,
)


