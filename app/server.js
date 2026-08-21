const express = require("express");
const amqp = require("amqplib");

const app = express();
const PORT = 3000;

app.use(express.json());

const RABBITMQ_URL = process.env.RABBITMQ_URL || "amqp://rabbitmq:5672";
const QUEUE_NAME = "orders";

async function publishOrder(order) {
    const connection = await amqp.connect(RABBITMQ_URL);
    const channel = await connection.createChannel();

    await channel.assertQueue(QUEUE_NAME, {
        durable: true
    });

    channel.sendToQueue(
        QUEUE_NAME,
        Buffer.from(JSON.stringify(order)),
        {
            persistent: true
        }
    );

    console.log("Order sent to RabbitMQ:", order);

    setTimeout(() => {
        connection.close();
    }, 500);
}

app.get("/", (req, res) => {
    res.json({
        message: "DevOps is running HOT RELOAD FINAL 1234!",
        status: "success"
    });
});

app.get("/hello", (req, res) => {
    res.json({
        message: "Hello from DevOps Platform!"
    });
});

app.get("/health", (req, res) => {
    res.json({
        status: "UP"
    });
});

app.post("/orders", async (req, res) => {
    const order = {
        id: Date.now(),
        product: req.body.product,
        quantity: req.body.quantity
    };

    try {
        await publishOrder(order);

        res.status(202).json({
            message: "Order accepted and sent to queue",
            order
        });
    } catch (error) {
        console.error("Failed to publish order:", error);

        res.status(500).json({
            message: "Failed to send order to RabbitMQ"
        });
    }
});

app.listen(PORT, () => {
    console.log(`Application running on http://localhost:${PORT}`);
});
