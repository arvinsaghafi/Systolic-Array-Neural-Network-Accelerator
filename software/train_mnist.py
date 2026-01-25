import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms
import numpy as np
import os

# Neural Network
class FPGA_MLP(nn.Module):
    def __init__(self):
        super(FPGA_MLP, self).__init__()
        self.fc1 = nn.Linear(784, 64, bias=False)
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(64, 10, bias=False)
    
    def forward(self, x):
        x = x.view(-1, 784)
        x = self.fc1(x)
        x = self.relu(x)
        x = self.fc2(x)
        return x
    
def train():
    transform = transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.5,), (0.5,))])
    
    print("Downloading MNIST dataset...")
    train_dataset = datasets.MNIST('./data', train=True, download=True, transform=transform)
    train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=64, shuffle=True)

    model = FPGA_MLP()
    optimizer = optim.SGD(model.parameters(), lr=0.01)
    criterion = nn.CrossEntropyLoss()

    print("Starting training, this might take a minute...")
    model.train()

    for batch_idx, (data, target) in enumerate(train_loader):
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()

        if batch_idx % 100 == 0:
            print(f"Batch {batch_idx}/{len(train_loader)} \tLoss: {loss.item():.4f}")

    print("Training complete.")
    return model

# Export to INT8 FPGA format
def export_weights(model):
    print("\n Exporting weights for Verilog")
    weights = model.fc1.weight.detach().numpy().T

    max_val = np.abs(weights).max()
    scale_factor = 127.0 / max_val

    weights_int8 = np.round(weights * scale_factor).astype(np.int8)

    print(f"Layer 1 weights shape: {weights_int8.shape}")
    print(f"Max float value: {max_val:.4f}")
    print(f"Scale factor: {scale_factor:.4f}")

    # np.savetxt("fc1_weights.txt", weights_int8, fmt='%d')
    
    print("\n Saving test image")
    test_dataset = datasets.MNIST('./data', train=False, download=True,
                                  transform=transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.5,), (0.5,))]))
    
    img_tensor, label = test_dataset[0]
    img_numpy = img_tensor.numpy().flatten()

    img_int8 = np.round(img_numpy * 127.0).astype(np.int8)

    # np.savetxt("test_image.txt", img_int8, fmt='%d')

    def save_as_hex(filename, data):
        with open(filename, 'w') as f:
            for val in data.flatten():
                f.write(f'{int(val) & 0xff:02x}\n')
    
    save_as_hex("fc1_weights.txt", weights_int8)
    print("Saved 'fc1_weights.txt', load this in your Verilog testbench.")
    save_as_hex("test_image.txt", img_int8)
    print(f"Saved 'test_image.txt', Correct label is: {label}")

if __name__ == "__main__":
    trained_model = train()
    export_weights(trained_model)