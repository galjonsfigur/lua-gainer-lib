local ffi = require("ffi")

ffi.cdef[[

static const int VINTR = 0;
static const int VQUIT = 1;
static const int VERASE = 2;
static const int VKILL = 3;
static const int VEOF = 4;
static const int VTIME = 5;
static const int VMIN = 6;
static const int VSWTC = 7;
static const int VSTART = 8;
static const int VSTOP = 9;
static const int VSUSP = 10;
static const int VEOL = 11;
static const int VREPRINT = 12;
static const int VDISCARD = 13;
static const int VWERASE = 14;
static const int VLNEXT = 15;
static const int VEOL2 = 16;

static const int IGNBRK =	0000001;
static const int BRKINT =	0000002;
static const int IGNPAR =	0000004;
static const int PARMRK =	0000010;
static const int INPCK =	0000020;
static const int ISTRIP =	0000040;
static const int INLCR =	0000100;
static const int IGNCR =	0000200;
static const int ICRNL =	0000400;
static const int IUCLC =	0001000;
static const int IXON =	0002000;
static const int IXANY =	0004000;
static const int IXOFF =	0010000;
static const int IMAXBEL =	0020000;
static const int IUTF8 =	0040000;

static const int OPOST =	0000001;
static const int OLCUC =	0000002;
static const int ONLCR =	0000004;
static const int OCRNL =	0000010;
static const int ONOCR =	0000020;
static const int ONLRET =	0000040;
static const int OFILL =	0000100;
static const int OFDEL =	0000200;
static const int VTDLY =	0040000;
static const int   VT0 =	0000000;
static const int   VT1 =	0040000;

static const int  B0 =	0000000;
static const int  B50 =	0000001;
static const int  B75 =	0000002;
static const int  B110 =	0000003;
static const int  B134 =	0000004;
static const int  B150 =	0000005;
static const int  B200 =	0000006;
static const int  B300 =	0000007;
static const int  B600 =	0000010;
static const int  B1200 =	0000011;
static const int  B1800 =	0000012;
static const int  B2400 =	0000013;
static const int  B4800 =	0000014;
static const int  B9600 =	0000015;
static const int  B19200 =	0000016;
static const int  B38400 =	0000017;
static const int CSIZE =	0000060;
static const int   CS5 =	0000000;
static const int   CS6 =	0000020;
static const int   CS7 =	0000040;
static const int   CS8 =	0000060;
static const int CSTOPB =	0000100;
static const int CREAD =	0000200;
static const int PARENB =	0000400;
static const int PARODD =	0001000;
static const int HUPCL =	0002000;
static const int CLOCAL =	0004000;
static const int  B57600 =   0010001;
static const int  B115200 =  0010002;
static const int  B230400 =  0010003;
static const int  B460800 =  0010004;
static const int  B500000 =  0010005;
static const int  B576000 =  0010006;
static const int  B921600 =  0010007;
static const int  B1000000 = 0010010;
static const int  B1152000 = 0010011;
static const int  B1500000 = 0010012;
static const int  B2000000 = 0010013;
static const int  B2500000 = 0010014;
static const int  B3000000 = 0010015;
static const int  B3500000 = 0010016;
static const int  B4000000 = 0010017;
static const int __MAX_BAUD = B4000000;

typedef struct termios {
	unsigned int c_iflag;
	unsigned int c_oflag;
	unsigned int c_cflag;
	unsigned int c_lflag;
	unsigned char c_line;
	unsigned char c_cc[32];
	unsigned int c_ispeed;
	unsigned int c_ospeed;
}termios_t;

static const int	TCOOFF =		0;
static const int	TCOON =		1;
static const int	TCIOFF =		2;
static const int	TCION =		3;

static const int	TCIFLUSH =	0;
static const int	TCOFLUSH =	1;
static const int	TCIOFLUSH =	2;

static const int	TCSANOW =		0;
static const int	TCSADRAIN =	1;
static const int	TCSAFLUSH =	2;

static const int O_RDONLY =	00000000;
static const int O_WRONLY =	00000001;
static const int O_RDWR =		00000002;
static const int O_APPEND  = 00002000;
static const int O_NONBLOCK = 00004000;


int printf(const char *fmt, ...);
int open(const char *pathname, int flags);
int tcsetattr(int fd, int optional_actions, const struct termios *termios_p);
int tcdrain(int fd);
int fcntl(int fd, int cmd, ...);
int write(int fd, const void *buf, int count);
int read(int fd, void *buf, int count);
int ioctl(int fildes, int request, ...);


void Sleep(int ms);
int poll(struct pollfd *fds, unsigned long nfds, int timeout);
]]

local C=ffi.C;

local nativeFunctions = {}
nativeFunctions.serial = {}

if ffi.os == "Windows" then
  function nativeFunctions.sleep(s)
    ffi.C.Sleep(s*1000)
  end
else
  function nativeFunctions.sleep(s)
    ffi.C.poll(nil, 0, s*1000)
  end
end


function nativeFunctions.serial.setBaud(baud)
	if (nativeFunctions.serial.fd < 0) then
		return -1;
	end

	local t = ffi.new("termios_t");
	t.c_cflag = bit.bor(baud, C.CS8, C.CLOCAL, C.CREAD);
    t.c_iflag = 0;
	t.c_oflag = 0;
	t.c_lflag = 0;
	if (C.tcsetattr(nativeFunctions.serial.fd, C.TCSADRAIN, t) ~= 0) then
		print("Error setting termios");
		return false;
	else
		return true;
	end
end

function nativeFunctions.serial.open(path)
	print("Opening " .. path);
	-- O_RDWR = 2
	nativeFunctions.serial.fd = ffi.C.open(path, bit.bor(C.O_RDWR, C.O_NONBLOCK));
	if (nativeFunctions.serial.fd < 0) then
		print("Error opening " .. path);
		return false;
	else
		return true;
	end
end

function nativeFunctions.serial.write(data)
	if (nativeFunctions.serial.fd < 0) then
		return -1;
	end

	return C.write(nativeFunctions.serial.fd, data, #data);
end

function nativeFunctions.serial.read()
	local ret = ""
	local bufsize = 256;
	local buf = ffi.new("uint8_t[?]", bufsize);
	local cnt;
	while true do
		cnt = C.read(nativeFunctions.serial.fd, buf, bufsize);
		if cnt <= 0 then
			break;
		end
		ret = ret .. ffi.string(buf, cnt)
	end

	return ret;
end

function nativeFunctions.serial.drain()
	C.tcdrain(nativeFunctions.serial.fd);
end

-- add C constants and functions to serial object
setmetatable(nativeFunctions.serial, { __index = C })

return nativeFunctions

