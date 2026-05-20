import {
  HttpClient,
  HttpClientRequest,
  HttpApi,
  HttpApiBuilder,
  HttpApiEndpoint,
  HttpApiGroup,
  HttpApiSwagger
} from "@effect/platform"
import { NodeContext, NodeHttpClient, NodeHttpServer, NodeRuntime } from "@effect/platform-node"
import { Effect, Layer, Schedule, Schema } from "effect"
import { createServer } from "node:http"

class ServerError extends Schema.TaggedClass<ServerError>("ServerError")("ServerError", {
  message: Schema.String,
}) {}

class RandomError extends Schema.TaggedClass<RandomError>("RandomError")("RandomError", {
  message: Schema.String,
}) {}

const MyApi = HttpApi.make("MyApi").add(
  HttpApiGroup.make("Greetings").add(
    HttpApiEndpoint.get("hello-world")`/`
      .addSuccess(Schema.String)                    // 200
      .addSuccess(Schema.Void, { status: 204 })     // 204 No Content
      .addError(ServerError, { status: 500 })        // 500
      .addError(RandomError, { status: 418 })        // 418 with JSON
  )
)

const GreetingsLive = HttpApiBuilder.group(MyApi, "Greetings", (handlers) =>
  handlers.handle("hello-world", () => {
    const roll = Math.floor(Math.random() * 4)
    switch (roll) {
      case 0:
        return Effect.succeed("Hello, World!")        // → 200
      case 1:
        return Effect.void                              // → 204
      case 2:
        return Effect.fail(new ServerError({ message: "Internal Server Error" }))  // → 500
      case 3: {
        const errors = [
          { message: "I'm a teapot" },
          { message: "Rate limited" },
          { message: "Unauthorized" },
        ]
        const err = errors[Math.floor(Math.random() * errors.length)]
        return Effect.fail(new RandomError(err))       
      }
      default:
        return Effect.succeed("Hello, World!")
    }
  })
)

const MyApiLive = HttpApiBuilder.api(MyApi).pipe(Layer.provide(GreetingsLive))

const cronEffect = Effect.gen(function* () {
  const client = yield* HttpClient.HttpClient
  const cronClient = client.pipe(
    HttpClient.mapRequest(HttpClientRequest.prependUrl("http://localhost:3000"))
  )
  yield* Effect.fork(
    Effect.repeat(
      Effect.gen(function* () {
        const response = yield* cronClient.get("/")
        yield* Effect.log(`Cron hit: ${response.status}`)
      }).pipe(
        Effect.retry(Schedule.exponential("1 second", 2)),
        Effect.catchAll(() => Effect.log("Cron request gave up, will retry next minute"))
      ),
      Schedule.fixed("1 minute")
    )
  )
})

const CronLive = Layer.scopedDiscard(
  cronEffect.pipe(
    Effect.provide(NodeHttpClient.layer),
    Effect.provide(NodeContext.layer)
  )
)

const ServerLive = HttpApiBuilder.serve().pipe(
  Layer.provide(HttpApiSwagger.layer()),
  Layer.provide(MyApiLive),
  Layer.provide(NodeHttpServer.layer(createServer, { port: 3000 }))
)

Layer.launch(Layer.merge(ServerLive, CronLive)).pipe(NodeRuntime.runMain)
