import copy
import json
import random
from pathlib import Path
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms

SEED = 0
BATCH_SIZE = 64
EPOCHS = 1

SOFTWARE_DIR = Path(__file__).resolve().parent
DATA_DIR = SOFTWARE_DIR / "data"

class FPGA_MLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(784, 64, bias=False)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(64, 10, bias=False)

    def forward(self, x):
        x = x.view(-1, 784)
        x = self.fc1(x)
        x = self.relu(x)
        return self.fc2(x)


def set_seed():
    random.seed(SEED)
    np.random.seed(SEED)
    torch.manual_seed(SEED)


def make_datasets():
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((0.5,), (0.5,)),
    ])

    train_dataset = datasets.MNIST(
        str(DATA_DIR),
        train=True,
        download=True,
        transform=transform,
    )

    test_dataset = datasets.MNIST(
        str(DATA_DIR),
        train=False,
        download=True,
        transform=transform,
    )

    return train_dataset, test_dataset


def train(model, train_dataset):
    generator = torch.Generator().manual_seed(SEED)

    train_loader = torch.utils.data.DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        generator=generator,
    )

    optimizer = optim.SGD(model.parameters(), lr=0.01)
    criterion = nn.CrossEntropyLoss()

    print(f"Training for {EPOCHS} epoch on {len(train_dataset):,} MNIST images")
    model.train()

    for epoch in range(EPOCHS):
        for batch_index, (data, target) in enumerate(train_loader):
            optimizer.zero_grad()
            loss = criterion(model(data), target)
            loss.backward()
            optimizer.step()

            if batch_index % 100 == 0:
                print(
                    f"Epoch {epoch + 1}, batch {batch_index}/"
                    f"{len(train_loader)}, loss={loss.item():.4f}"
                )

    return model


def evaluate(model, test_dataset):
    test_loader = torch.utils.data.DataLoader(
        test_dataset,
        batch_size=1000,
        shuffle=False,
    )

    correct = 0
    model.eval()

    with torch.inference_mode():
        for data, target in test_loader:
            predictions = model(data).argmax(dim=1)
            correct += (predictions == target).sum().item()

    return 100.0 * correct / len(test_dataset)


def quantize_tensor(tensor):
    max_abs = tensor.abs().max().item()

    if max_abs == 0:
        return torch.zeros_like(tensor, dtype=torch.int8), 1.0

    scale = max_abs / 127.0
    quantized = torch.clamp(
        torch.round(tensor / scale),
        -127,
        127,
    ).to(torch.int8)

    return quantized, scale


def make_weight_quantized_model(
    model,
    fc1_quantized,
    fc1_scale,
    fc2_quantized,
    fc2_scale,
):
    quantized_model = copy.deepcopy(model)

    with torch.no_grad():
        quantized_model.fc1.weight.copy_(
            fc1_quantized.float() * fc1_scale
        )

        quantized_model.fc2.weight.copy_(
            fc2_quantized.float() * fc2_scale
        )

    return quantized_model


def save_hex(filename, data):
    output_path = SOFTWARE_DIR / filename

    with output_path.open("w") as file:
        for value in data.reshape(-1):
            file.write(f"{int(value) & 0xff:02x}\n")

    return output_path


def export_artifacts(
    model,
    test_dataset,
    fp32_accuracy,
    training_images,
):
    fc1_quantized, fc1_scale = quantize_tensor(
        model.fc1.weight.detach()
    )

    fc2_quantized, fc2_scale = quantize_tensor(
        model.fc2.weight.detach()
    )

    quantized_model = make_weight_quantized_model(
        model,
        fc1_quantized,
        fc1_scale,
        fc2_quantized,
        fc2_scale,
    )

    quantized_accuracy = evaluate(
        quantized_model,
        test_dataset,
    )

    # Transpose into input-major order for SystemVerilog memory.
    fc1_path = save_hex(
        "fc1_weights.txt",
        fc1_quantized.T.cpu().numpy(),
    )

    fc2_path = save_hex(
        "fc2_weights.txt",
        fc2_quantized.T.cpu().numpy(),
    )

    image, label = test_dataset[0]

    image_quantized = torch.clamp(
        torch.round(image.flatten() * 127.0),
        -127,
        127,
    ).to(torch.int8)

    image_path = save_hex(
        "test_image.txt",
        image_quantized.cpu().numpy(),
    )

    total_weights = fc1_quantized.numel() + fc2_quantized.numel()
    fp32_bytes = total_weights * 4
    int8_bytes = total_weights
    memory_reduction = 100.0 * (
        fp32_bytes - int8_bytes
    ) / fp32_bytes

    report = {
        "seed": SEED,
        "epochs": EPOCHS,
        "training_images": training_images,
        "test_images": len(test_dataset),
        "fp32_test_accuracy_percent": fp32_accuracy,
        "int8_weight_quantized_test_accuracy_percent": (
            quantized_accuracy
        ),
        "accuracy_change_percentage_points": (
            quantized_accuracy - fp32_accuracy
        ),
        "fc1_weight_count": fc1_quantized.numel(),
        "fc2_weight_count": fc2_quantized.numel(),
        "total_weight_count": total_weights,
        "fp32_weight_bytes": fp32_bytes,
        "int8_weight_bytes": int8_bytes,
        "weight_memory_reduction_percent": memory_reduction,
        "fc1_scale": fc1_scale,
        "fc2_scale": fc2_scale,
        "test_image_label": int(label),
    }

    report_path = SOFTWARE_DIR / "quantization_report.json"

    with report_path.open("w") as file:
        json.dump(report, file, indent=2)
        file.write("\n")

    print(f"FP32 test accuracy: {fp32_accuracy:.2f}%")
    print(
        "INT8 weight-quantized test accuracy: "
        f"{quantized_accuracy:.2f}%"
    )
    print(
        "Accuracy change: "
        f"{quantized_accuracy - fp32_accuracy:+.2f} percentage points"
    )
    print(
        f"Weights: {total_weights:,} values, "
        f"{fp32_bytes:,} FP32 bytes -> {int8_bytes:,} INT8 bytes"
    )
    print(f"Weight memory reduction: {memory_reduction:.1f}%")
    print(f"Saved {fc1_path}")
    print(f"Saved {fc2_path}")
    print(f"Saved {image_path} with label {label}")
    print(f"Saved {report_path}")


def main():
    set_seed()
    train_dataset, test_dataset = make_datasets()

    model = train(
        FPGA_MLP(),
        train_dataset,
    )

    fp32_accuracy = evaluate(
        model,
        test_dataset,
    )

    export_artifacts(
        model,
        test_dataset,
        fp32_accuracy,
        len(train_dataset),
    )


if __name__ == "__main__":
    main()