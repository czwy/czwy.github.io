---
categories:
- IoT
date: 2025-02-19 14:49
last_modified_at: 2025-03-23 18:20:38 +0800
mtime: 2025-02-20 15:33:29
tags:
- IoT
- dotnet
- RFID
- ISO15693
- ISO14443
- 树莓派
title: RFID实践——NET IoT程序读取高频RFID卡或者标签
---

这篇文章是一份RFID实践的保姆级教程，将详细介绍如何用 Raspberry Pi 连接 PN5180 模块，并开发 .NET IoT 程序读写ISO14443 和 ISO15693协议的卡/标签。
## 设备清单
- Raspberry Pi必需套件（主板、电源、TF卡）
- PN5180 
- ISO15693标签
- 杜邦线
- 面包板 ( 可选)
- GPIO扩展板 (可选 )
本文中用到的树莓派型号是 Raspberry Pi Zero 2 W，电源直接使用充电宝替代（官方电源是5.1V / 2.5A DC）。
<a href="/posts/rfid基础-高频rfid协议-读写模块和标签/">RFID基础——高频RFID协议、读写模块和标签</a>中介绍过 PN5180 是一款价格便宜且支持全部高频 RFID 协议的读写模块。网购 PN5180 模块时通常会送一张ICODE SLIX卡和 Mifare S50 卡。
ISO15693标签选用的是国产的复旦微电子芯片的标签。额外购买是为了测试多张标签同时在射频场中防碰撞功能。
杜邦线用于连接  Raspberry Pi Zero 2 W 和 PN5180 模块。GPIO扩展板会标注逻辑引脚，配合面包板使用，方便连接多种传感器。

## 树莓派连接 PN5180
在 PN5180 上，您会注意到它上有13个引脚，这些引脚中只有9个是需要连接到树莓派的GPIO引脚。对应关系如下表所示。表中特意标注出逻辑引脚和物理引脚，是因为后边程序中需要设置引脚编号。详情在后续代码部分会进行解释。

| NXP5180 | 逻辑引脚                | 物理引脚 |
| ------- | ------------------- | ---- |
| +5V     | 5V                  | 2    |
| +3.3V   | 3V3                 | 1    |
| RST     | GPIO4(*GPCLK0*)     | 7    |
| NSS     | GPIO3(*SCL*)        | 5    |
| MOSI    | GPIO10(*SPI0-MOSI*) | 19   |
| MISO    | GPIO9(*SPI0-MISO*)  | 21   |
| SCK     | GPIO11(*SPI0-SCLK*) | 23   |
| BUSY    | GPIO2(*SDA*)        | 3    |
| GND     | GND                 | 9    |
| GPIO    | -                   |      |
| IRQ     | -                   |      |
| AUX     | -                   |      |
| REQ     | -                   |      |

下图灰色区域中 1~40 是物理引脚编号，两侧标注的是逻辑引脚，例如物理引脚编号3的标注是 GPIO2 ，也就是对应的逻辑引脚编号为2。
![gpio-pinout-diagram.png (1881×1080)](https://learn.microsoft.com/zh-cn/dotnet/iot/media/gpio-pinout-diagram.png#lightbox)
到了这里，准备工作已经完成，接下来就是编码了。

## 编写.NET IoT程序
.NET IoT库中已经实现了 PN5180 的部分功能。比如轮询 ISO14443-A 和 ISO14443-B 类型的卡，以及对它们的读写操作，但是没有实现对 ISO15693 协议卡的支持。
PN5180通过SPI和GPIO进行工作，它以特定的方式通过GPIO使用SPI进行通信。这就需要手动管理SPI的引脚选择，`Busy` 引脚用于了解 PN5180 什么时候可以接收和发送信息。
首先，引用- [System.Device.Gpio](https://www.nuget.org/packages/System.Device.Gpio/)和 [Iot.Device.Bindings](https://www.nuget.org/packages/Iot.Device.Bindings/)两个包，然后用下面的代码创建SPI驱动程序、重置 PN5180 和创建 PN5180 实例。
``` csharp
var spi = SpiDevice.Create(new SpiConnectionSettings(0, 1) { ClockFrequency = Pn5180.MaximumSpiClockFrequency, Mode = Pn5180.DefaultSpiMode, DataFlow = DataFlow.MsbFirst });

// Reset the device
var gpioController = new GpioController();
gpioController.OpenPin(4, PinMode.Output);
gpioController.Write(4, PinValue.Low);
Thread.Sleep(10);
gpioController.Write(4, PinValue.High);
Thread.Sleep(10);

var pn5180 = new Pn5180(spi, 2, 3);
```
第1行代码创建 `SpiDevice` 实例，其中设置 `DataFlow = DataFlow.MsbFirst` ，即首先发送最高有效位。需要注意的是，这里指的是主机与 PN5180 模块之间的 SPI 总线的传输顺序，<a href="/posts/rfid基础-iso15693标签存储结构及访问控制命令说明/">RFID基础——ISO15693标签存储结构及访问控制命令说明</a>中协议中首先传输最低有效位指的是 VCD 与 VICC 之间的射频通信，两者是不同的数据传输过程。
第4行代码创建 `GpioController` 实例，[GpioController 类](https://learn.microsoft.com/zh-cn/dotnet/api/system.device.gpio.gpiocontroller?view=iot-dotnet-latest) 的无参构造函数使用逻辑引脚编号方案作为默认方案。
第5行代码开启编号4的引脚，这个编号也就是指的逻辑引脚编号 GPIO4。
第11行创建 PN5180 读写器实例。构造函数定义如下：
``` csharp
public Pn5180 (System.Device.Spi.SpiDevice spiDevice, int pinBusy, int pinNss, System.Device.Gpio.GpioController? gpioController = default, bool shouldDispose = true);
```
第一个参数是 spi 设备实例，第二个参数是 `Busy` 引脚编号，第三个参数是 `Nss` 引脚编号，这里都是指的逻辑编号。代码中的参数需和前面引脚对应表中指定的一致。
### 访问ISO14443协议卡
访问ISO14443协议卡比较简单，调用 `ListenToCardIso14443TypeA`, `ListenToCardIso14443TypeB` 轮询射频场中的 PICC，然后选中卡进行操作，下边是监听 ISO14443-A 和 ISO14443-B 类型卡的示例代码：
``` csharp
do
{
   if (pn5180.ListenToCardIso14443TypeA(TransmitterRadioFrequencyConfiguration.Iso14443A_Nfc_PI_106_106, ReceiverRadioFrequencyConfiguration.Iso14443A_Nfc_PI_106_106, out Data106kbpsTypeA? cardTypeA, 1000))
   {
	   Console.WriteLine($"ISO 14443 Type A found:");
	   Console.WriteLine($"  ATQA: {cardTypeA.Atqa}");
	   Console.WriteLine($"  SAK: {cardTypeA.Sak}");
	   Console.WriteLine($"  UID: {BitConverter.ToString(cardTypeA.NfcId)}");
   }
   else
   {
	   Console.WriteLine($"{nameof(cardTypeA)} is not configured correctly.");
   }

   if (pn5180.ListenToCardIso14443TypeB(TransmitterRadioFrequencyConfiguration.Iso14443B_106, ReceiverRadioFrequencyConfiguration.Iso14443B_106, out Data106kbpsTypeB? card, 1000))
   {
	   Console.WriteLine($"ISO 14443 Type B found:");
	   Console.WriteLine($"  Target number: {card.TargetNumber}");
	   Console.WriteLine($"  App data: {BitConverter.ToString(card.ApplicationData)}");
	   Console.WriteLine($"  App type: {card.ApplicationType}");
	   Console.WriteLine($"  UID: {BitConverter.ToString(card.NfcId)}");
	   Console.WriteLine($"  Bit rates: {card.BitRates}");
	   Console.WriteLine($"  Cid support: {card.CidSupported}");
	   Console.WriteLine($"  Command: {card.Command}");
	   Console.WriteLine($"  Frame timing: {card.FrameWaitingTime}");
	   Console.WriteLine($"  Iso 14443-4 compliance: {card.ISO14443_4Compliance}");
	   Console.WriteLine($"  Max frame size: {card.MaxFrameSize}");
	   Console.WriteLine($"  Nad support: {card.NadSupported}");
   }
   else
   {
	   Console.WriteLine($"{nameof(card)} is not configured correctly.");
   }
}
while (!Console.KeyAvailable);
```
有关 ISO14443协议的更多操作可以查看`Iot.Device.Bindings`中 PN5180 的文档[iot/src/devices/Pn5180 at main · dotnet/iot](https://github.com/dotnet/iot/tree/main/src/devices/Pn5180)。
### 访问ISO15693协议卡
由于`Iot.Device.Bindings`中的 PN5180 并没有实现对 ISO15693协议的支持，因此需要自行实现这部分功能。
PN5180 模块的工作原理可以简单的理解为主机向 PN5180 模块发送开启、配置射频场、操作卡/标签（VICC）的命令，PN5180 模块接收到操作卡/标签（VICC）的命令时，通过射频信号与卡/标签（VICC）进行数据交互。寻卡过程的步骤如下：
1. 加载ISO 15693协议到RF寄存器
2. 开启射频场
3. 清除中断寄存器IRQ_STATUS
4. 把PN5180设置为IDLE状态
5. 激活收发程序
6. 向卡/标签（VICC）发送16时隙防冲突的寻卡指令
7. 循环16次以下操作
	1. 读取RX_STATUS寄存器，判断是否有卡/标签响应
	2. 如果有响应，发送读卡指令然后读取卡的响应
	3. 在下一次射频通信中只发送EOF（帧结束）而不发送数据。
	4. 把PN5180设置为IDLE状态
	5. 激活收发程序
	6. 清除中断寄存器IRQ_STATUS
	7. 向卡/标签（VICC）发送EOF（帧结束）
8. 关闭射频场
上述步骤中只有步骤6`发送16时隙防冲突的寻卡指令`和步骤7.7`向卡/标签（VICC）发送EOF（帧结束）`是 PN5180 和卡/标签（VICC）之间的数据交互，其余的步骤都是PN5180 与主机之间通过SPI通信。
#### PN5180与主机通信
PN5180设计了24个主机接口命令，涉及读写寄存器、读写EEPROM、写数据到发送缓冲区，从接收缓冲区读数据，加载RF配置到寄存器，开启关闭射频场。包含44个寄存器，它们控制着PN5180处理器的行为。每个寄存器占4个字节。主机处理器可以通过4个不同的命令改变寄存器的值：`write_register`、 `write_register_and_mask`、 `write_register_or_mask`、`write_register_multiple`。
#####  write_register
这个命令将一个32位的值写入配置寄存器。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x00|
|参数|1|寄存器地址|
|参数|4|寄存器内容|

##### WRITE_REGISTER_OR_MASK
该命令使用逻辑或操作修改寄存器的内容。先读取寄存器的内容，并使用提供的掩码执行逻辑或操作，然后把修改后的内容写回寄存器。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x01|
|参数|1|寄存器地址|
|参数|4|逻辑或操作的掩码|

##### WRITE_REGISTER_AND_MASK
该命令使用逻辑与操作修改寄存器的内容。先读取寄存器的内容，并使用提供的掩码执行逻辑与操作，然后把修改后的内容写回寄存器。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x02|
|参数|1|寄存器地址|
|参数|4|逻辑与操作的掩码|

##### LOAD_RF_CONFIG
该命令用于将射频配置从EEPROM加载到配置寄存器中。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x11|
|参数|1|发送器配置的值|
|写入的数据|1|接收机配置的值|

##### RF_ON
该命令打开内部射频场。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x16|
|参数|1|1,根据 ISO/IEC 18092 禁用冲突避免|

##### RF_OFF
该命令关闭内部射频场

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x17|
|参数|1|虚字节|

#### PN5180和卡/标签（VICC）数据交互
PN5180和卡/标签（VICC）数据交互本质上也是主机发送命令给 PN5180 模块，然后 PN5180 把数据写入缓冲区，接着射频传输给卡/标签（VICC），卡/标签（VICC）响应后通过射频传出给 PN5180 模块的接收缓冲区，主机发送命令读取缓冲区数据。

##### SEND_DATA
该命令将数据写入射频传输缓冲区，开始射频传输。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x09|
|参数|1|最后一个字节的有效位数|
|写入的数据|1~260|最大长度为260的数组|

最后一个字节的有效位数为0表示最后一字节所有的bit都被传输，1~7表示要传输的最后一个字节内的位数。

##### READ_DATA
从VICC成功接收数据后，该命令从射频接收缓冲区读取数据。

|负载|长度|值/描述|
|--------|----|-------|
|命令编码|1|0x0A|
|参数|1|0x00|
|读取的数据|1~508|最大长度为508的数组|

#### 代码实现轮询ISO15693卡
PN5180 和卡/标签（VICC）之间的数据交互都是遵循<a href="/posts/rfid基础-iso15693标签存储结构及访问控制命令说明/">RFID基础——ISO15693标签存储结构及访问控制命令说明</a>中的命令。只需用代码实现 PN5180 的主机接口指令以及ISO15693的访问控制命令即可。首先Fork [dotnet/iot](https://github.com/dotnet/iot)版本库，然后在 `Pn5180.cs`中加入以下监听 ISO15693 协议卡的代码：
```csharp
/// <summary>
/// Listen to 15693 cards with 16 slots
/// </summary>
/// <param name="transmitter">The transmitter configuration, should be compatible with 15693 card</param>
/// <param name="receiver">The receiver configuration, should be compatible with 15693 card</param>
/// <param name="cards">The 15693 cards once detected</param>
/// <param name="timeoutPollingMilliseconds">The time to poll the card in milliseconds. Card detection will stop once the detection time will be over</param>
/// <returns>True if a 15693 card has been detected</returns>
public bool ListenToCardIso15693(TransmitterRadioFrequencyConfiguration transmitter, ReceiverRadioFrequencyConfiguration receiver,
#if NET5_0_OR_GREATER
[NotNullWhen(true)]
#endif
out IList<Data26_53kbps>? cards, int timeoutPollingMilliseconds)
{
	cards = new List<Data26_53kbps>();
	var ret = LoadRadioFrequencyConfiguration(transmitter, receiver);
	// Switch on the radio frequence field and check it
	ret &= SetRadioFrequency(true);

	Span<byte> inventoryResponse = stackalloc byte[10];
	Span<byte> dsfid = stackalloc byte[1];
	Span<byte> uid = stackalloc byte[8];

	int numBytes = 0;

	DateTime dtTimeout = DateTime.Now.AddMilliseconds(timeoutPollingMilliseconds);

	try
	{
		// Clears all interrupt
		SpiWriteRegister(Command.WRITE_REGISTER, Register.IRQ_CLEAR, new byte[] { 0xFF, 0xFF, 0x0F, 0x00 });
		// Sets the PN5180 into IDLE state
		SpiWriteRegister(Command.WRITE_REGISTER_AND_MASK, Register.SYSTEM_CONFIG, new byte[] { 0xF8, 0xFF, 0xFF, 0xFF });
		// Activates TRANSCEIVE routine
		SpiWriteRegister(Command.WRITE_REGISTER_OR_MASK, Register.SYSTEM_CONFIG, new byte[] { 0x03, 0x00, 0x00, 0x00 });
		// Sends an inventory command with 16 slots
		ret = SendDataToCard(new byte[] { 0x06, 0x01, 0x00 });
		if (dtTimeout < DateTime.Now)
		{
			return false;
		}

		for (byte slotCounter = 0; slotCounter < 16; slotCounter++)
		{
			(numBytes, _) = GetNumberOfBytesReceivedAndValidBits();
			if (numBytes > 0)
			{
				ret &= ReadDataFromCard(inventoryResponse, inventoryResponse.Length);
				if (ret)
				{
					cards.Add(new Data26_53kbps(slotCounter, 0, 0, inventoryResponse[1], inventoryResponse.Slice(2, 8).ToArray()));
				}
			}

			// Send only EOF (End of Frame) without data at the next RF communication
			SpiWriteRegister(Command.WRITE_REGISTER_AND_MASK, Register.TX_CONFIG, new byte[] { 0x3F, 0xFB, 0xFF, 0xFF });
			// Sets the PN5180 into IDLE state
			SpiWriteRegister(Command.WRITE_REGISTER_AND_MASK, Register.SYSTEM_CONFIG, new byte[] { 0xF8, 0xFF, 0xFF, 0xFF });
			// Activates TRANSCEIVE routine
			SpiWriteRegister(Command.WRITE_REGISTER_OR_MASK, Register.SYSTEM_CONFIG, new byte[] { 0x03, 0x00, 0x00, 0x00 });
			// Clears the interrupt register IRQ_STATUS
			SpiWriteRegister(Command.WRITE_REGISTER, Register.IRQ_CLEAR, new byte[] { 0xFF, 0xFF, 0x0F, 0x00 });
			// Send EOF
			SendDataToCard(new Span<byte> { });
		}

		if (cards.Count > 0)
		{
			return true;
		}
		else
		{
			return false;
		}
	}
	catch (TimeoutException)
	{
		return false;
	}
}
```

需要注意的是，寻卡指令`SendDataToCard(new byte[] { 0x06, 0x01, 0x00 })`发送的数据只有请求标志、命令、掩码长度，并没有CRC校验码，我推测是 PN5180 内部进行了CRC校验，目前并没有找到相关资料说明这点。同样，用 PN5180 读写标签数据块以及其他访问控制指令也不需要CRC校验码。

#### 读写ISO15693协议卡
由于支持 ISO15693 协议的读写器不只是 PN5180 ，因此把对 ISO15693 协议卡的具体读写操作放在 PN5180 的实现类中不太合适。这里定义了一个 `IcodeCard` 的类型，该类实现了 ISO15693 协议中常用的命令，并在构造函数中注入 RFID 读写器。执行指定操作时，调用 RFID 读写器的 `Transceive` 方法传输请求指令并接收响应进行处理。以下是主要代码：
``` csharp
public class IcodeCard
{
	public IcodeCard(CardTransceiver rfid, byte target)
	{
		_rfid = rfid;
		Target = target;
		_logger = this.GetCurrentClassLogger();
	}
	
	/// <summary>
	/// Run the last setup command. In case of reading bytes, they are automatically pushed into the Data property
	/// </summary>
	/// <returns>-1 if the process fails otherwise the number of bytes read</returns>
	private int RunIcodeCardCommand()
	{
		byte[] requestData = Serialize();
		byte[] dataOut = new byte[_responseSize];

		var ret = _rfid.Transceive(Target, requestData, dataOut.AsSpan(), NfcProtocol.Iso15693);
		_logger.LogDebug($"{nameof(RunIcodeCardCommand)}: {_command}, Target: {Target}, Data: {BitConverter.ToString(requestData)}, Success: {ret}, Dataout: {BitConverter.ToString(dataOut)}");
		if (ret > 0)
		{
			Data = dataOut;
		}

		return ret;
	}

	/// <summary>
	/// Serialize request data according to the protocol
	/// Request format: SOF, Flags, Command code, Parameters (opt.), Data (opt.), CRC16, EOF
	/// </summary>
	/// <returns>The serialized bits</returns>
	private byte[] Serialize()
	{
		byte[]? ser = null;
		switch (_command)
		{
			case IcodeCardCommand.ReadSingleBlock:
				// Flags(1 byte), Command code(1 byte), UID(8 byte), BlockNumber(1 byte)
				ser = new byte[2 + 8 + 1];
				ser[0] = 0x22;
				ser[1] = (byte)_command;
				ser[10] = BlockNumber;
				Uid?.CopyTo(ser, 2);
				_responseSize = 5;
				return ser;
			// 略去代码....
			default:
				return new byte[0];
		}
	}

	/// <summary>
	/// Perform a read and place the result into the 4 bytes Data property on a specific block
	/// </summary>
	/// <param name="block">The block number to read</param>
	/// <returns>True if success. This only means whether the communication between VCD and VICC is successful or not </returns>
	public bool ReadSingleBlock(byte block)
	{
	    BlockNumber = block;
	    _command = IcodeCardCommand.ReadSingleBlock;
	    var ret = RunIcodeCardCommand();
	    return ret >= 0;
	}
}
```
只需以下代码就可以监听射频场中的 ISO15693 类型的卡并进行读写操作：
``` csharp
if (pn5180.ListenToCardIso15693(TransmitterRadioFrequencyConfiguration.Iso15693_ASK100_26, ReceiverRadioFrequencyConfiguration.Iso15693_26, out IList<Data26_53kbps>? cards, 20000))
{
    pn5180.ResetPN5180Configuration(TransmitterRadioFrequencyConfiguration.Iso15693_ASK100_26, ReceiverRadioFrequencyConfiguration.Iso15693_26);
    foreach (Data26_53kbps card in cards)
    {
        Console.WriteLine($"Target number: {card.TargetNumber}");
        Console.WriteLine($"UID: {BitConverter.ToString(card.NfcId)}");
        Console.WriteLine($"DSFID: {card.Dsfid}");
        if (card.NfcId[6] == 0x04)
{
    IcodeCard icodeCard = new IcodeCard(pn5180, card.TargetNumber)
    {
        Afi = 1,
        Dsfid= 1,
        Uid = card.NfcId,
        Capacity = IcodeCardCapacity.IcodeSlix,
    };
    
    for (byte i = 0; i < 28; i++)
    {
        if (icodeCard.ReadSingleBlock(i))
        {
            Console.WriteLine($"Block {i} data is :{BitConverter.ToString(icodeCard.Data)}");
        }
        else
        {
            icodeCard.Data = new byte[] { };
        }
    }
}
else
{
    Console.WriteLine("Only Icode cards are supported");
}
    }
}
```
最后，就是把程序部署到 Raspberry pi 上，具体操作可以参照<a href="/posts/raspberry-pi-上部署调试dotnet的iot程序/">Raspberry pi 上部署调试dotnet的IoT程序</a>。