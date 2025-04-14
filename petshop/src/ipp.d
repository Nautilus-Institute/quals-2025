module ipp;

import std.stdio;
import std.conv;
import std.string;
import std.socket;
import std.bitmanip;
import std.algorithm;

enum IPPVersion : ushort
{
    Version1_1 = 0x0101,
    Version2_0 = 0x0200,
}

enum IPPOperation : ushort
{
    PrintJob = 0x0002,
    PrintUri = 0x0003,
    ValidateJob = 0x0004,
    CreateJob = 0x0005,
    SendDocument = 0x0006,
    SendUri = 0x0007,
    CancelJob = 0x0008,
    GetJobAttributes = 0x0009,
    GetJobs = 0x000A,
    GetPrinterAttributes = 0x000B,
    HoldJob = 0x000C,
    ReleaseJob = 0x000D,
    RestartJob = 0x000E,
    PausePrinter = 0x0010,
    ResumePrinter = 0x0011,
    PurgeJobs = 0x0012,
    SetPrinterAttributes = 0x0013,
    SetJobAttributes = 0x0014,
}

enum IPPTag : ubyte
{
    OperationAttributes = 0x01,
    JobAttributes = 0x02,
    EndOfAttributes = 0x03,
    PrinterAttributes = 0x04,
    UnsupportedAttributes = 0x05,
    SubscriptionAttributes = 0x06,
    EventNotificationAttributes = 0x07,
    ResourceAttributes = 0x08,
    DocumentAttributes = 0x09,
    SystemAttributes = 0x0A,
    UnsolicitedJobAttributes = 0x0B,
    Unsupported = 0x10,
    Unknown = 0x12,
    NoValue = 0x13,
    NotSettable = 0x15,
    DeleteAttribute = 0x16,
    AdminDefine = 0x17,
    AdminDelete = 0x18,
    AdminAdd = 0x19,
    AdminReplace = 0x1A,
    AdminRemove = 0x1B,
    Integer = 0x21,
    Boolean = 0x22,
    Enum = 0x23,
    OctetString = 0x30,
    DateTime = 0x31,
    Resolution = 0x32,
    RangeOfInteger = 0x33,
    BegCollection = 0x34,
    TextWithLanguage = 0x35,
    NameWithLanguage = 0x36,
    EndCollection = 0x37,
    TextWithoutLanguage = 0x41,
    NameWithoutLanguage = 0x42,
    Keyword = 0x44,
    Uri = 0x45,
    UriScheme = 0x46,
    Charset = 0x47,
    NaturalLanguage = 0x48,
    MimeMediaType = 0x49,
    MemberAttrName = 0x4A
}


struct Attribute
{
    string name;
    ubyte[] value;
    bool ignore_name = false;
}


class IPPRequest
{
    private IPPVersion ver;
    private IPPOperation operation;
    private int request_id;

    private Attribute[] operation_attributes;
    private Attribute[] job_attributes;
    private Attribute[] printer_attributes;
    private ubyte[] data;

    this(IPPVersion ver, IPPOperation operation, int request_id = 1337)
    {
        this.ver = ver;
        this.operation = operation;
        this.request_id = request_id;
    }

    IPPTag getTag(string name)
    {
        switch (name)
        {
            case "job-name":
                return IPPTag.NameWithoutLanguage;
            case "requesting-user-name":
                return IPPTag.NameWithoutLanguage;
            case "document-format":
                return IPPTag.MimeMediaType;
            case "attributes-charset":
                return IPPTag.Charset;
            case "attributes-natural-language":
                return IPPTag.NaturalLanguage;
            case "printer-uri":
                return IPPTag.Uri;
            case "printer-name":
                return IPPTag.NameWithoutLanguage;
            case "printer-location":
                return IPPTag.TextWithoutLanguage;
            case "printer-info":
                return IPPTag.TextWithoutLanguage;
            case "printer-make-and-model":
                return IPPTag.TextWithoutLanguage;
            case "printer-state":
                return IPPTag.Integer;
            case "printer-state-reasons":
                return IPPTag.Keyword;
            case "printer-state-message":
                return IPPTag.TextWithoutLanguage;
            case "printer-state-reason":
                return IPPTag.Keyword;
            case "printer-device-id":
                return IPPTag.TextWithoutLanguage;
            case "printer-type":
                return IPPTag.TextWithoutLanguage;
            case "requested-attributes":
                return IPPTag.Keyword;
            case "printer-diagnostic-info":
                return IPPTag.TextWithoutLanguage;
            default:
                return IPPTag.Unknown;
        }
    }

    void addOperationAttribute(string name, ubyte[] value)
    {
        operation_attributes ~= Attribute(name, value);
    }

    void addOperationAttribute(string name, string[] value)
    {
        int i = 0;
        foreach (val; value) {
            Attribute attr;
            if (i == 0) {
                attr = Attribute(name, cast(ubyte[])val);
            } else {
                attr = Attribute(name, cast(ubyte[])val, true);
            }
            operation_attributes ~= attr;
            i += 1;
        }
    }

    void addData(ubyte[] data)
    {
        this.data = data;
    }

    ubyte[] serialize()
    {
        ubyte[] request_data = [
            cast(ubyte)(ver >> 8), cast(ubyte)(ver & 0xFF),  // Version (2 bytes)
            cast(ubyte)(operation >> 8), cast(ubyte)(operation & 0xFF),  // Operation (2 bytes)
            cast(ubyte)(request_id >> 24), cast(ubyte)(request_id >> 16),  // Request ID (4 bytes)
            cast(ubyte)(request_id >> 8), cast(ubyte)(request_id & 0xFF),
        ];

        // Operation attributes
        // Add attribute tag
        request_data ~= cast(ubyte)IPPTag.OperationAttributes;
        foreach (attr; operation_attributes) {
            auto name = attr.name;
            auto value = attr.value;

            IPPTag tag = getTag(name);
            if (tag == IPPTag.Unknown)
            {
                throw new Exception("Unknown attribute: " ~ attr.name);
            }
            request_data ~= cast(ubyte)(tag);

            // add name length and name
            if (!attr.ignore_name) {
                request_data ~= cast(ubyte)(name.length >> 8);
                request_data ~= cast(ubyte)(name.length & 0xFF);
                request_data ~= cast(ubyte[])name;
            } else {
                request_data ~= cast(ubyte)(0);
                request_data ~= cast(ubyte)(0);
            }
            
            // Add value length and value
            request_data ~= cast(ubyte)(value.length >> 8);
            request_data ~= cast(ubyte)(value.length & 0xFF);
            request_data ~= value;
        }

        // Job attributes

        // Printer attributes

        // data
        request_data ~= cast(ubyte)IPPTag.EndOfAttributes;  // End attributes tag
        request_data ~= data;

        return request_data;
    }
}

class IPPClient
{
    private string host;
    private ushort port;
    private ubyte[] last_response;

    this(string host, ushort port)
    {
        this.host = host;
        this.port = port;
        this.last_response = new ubyte[0];
    }

    ubyte[] readUntilNewline(Socket socket)
    {
        // read until we get a newline
        ubyte[] buffer = new ubyte[0];
        ubyte[] ch = new ubyte[1];
        long bytes_read = socket.receive(ch);
        while (bytes_read > 0) {
            buffer ~= ch;
            if (ch[0] == '\n') {
                break;
            }
            bytes_read = socket.receive(ch);
        }
        return buffer;
    }

    ubyte[] getLastResponse()
    {
        return last_response;
    }

    bool sendRequest(IPPRequest request)
    {
        try {
            auto socket = new Socket(AddressFamily.INET, SocketType.STREAM);
            socket.connect(new InternetAddress(host, port));

            ubyte[] request_data = request.serialize();

            // Create HTTP request
            string http_request = format("POST /ipp/print HTTP/1.1\r\n"
            ~"Host: %s:%d\r\n"
            ~"Content-Type: application/ipp\r\n"
            ~"Accept: application/ipp, text/plain, */*\r\n"
            ~"Content-Length: %d\r\n"
            ~"Connection: close\r\n"
            ~"User-Agent: MyIpp\r\n"
            ~"\r\n",
            host, port, request_data.length);

            // Send HTTP request
            socket.send(cast(ubyte[])http_request);
            socket.send(request_data);

            // Read response
            ubyte[] header = readUntilNewline(socket);

            // Check if we got a valid HTTP response
            if (header.length > 0) {
                if ((cast(string)header).startsWith("HTTP/1.1 200")) {
                    // find Content-Length
                    int content_length = 0;
                    bool chunked = false;
                    while (true) {
                        ubyte[] attr = readUntilNewline(socket);
                        string attr_str = cast(string)attr;
                        if (attr_str == "\r\n") {
                            break;
                        }
                        if (canFind(attr_str, "Transfer-Encoding: chunked")) {
                            chunked = true;
                        }
                        if (canFind(attr_str, "Content-Length: ")) {
                            string second_part = attr_str.split(": ")[1];
                            if (second_part.length > 2 && second_part[second_part.length - 2] == '\r' && second_part[second_part.length - 1] == '\n') {
                                second_part = second_part[0 .. second_part.length - 2];
                            }
                            content_length = second_part.to!int;
                        }
                    }
                    if (content_length > 0) {
                        this.last_response = new ubyte[content_length];
                        socket.receive(this.last_response);
                    } else if (chunked) {
                        // we only parse the first chunk

                        // read the first line
                        ubyte[] line = readUntilNewline(socket);
                        string line_str = cast(string)line;
                        if (line_str.length > 2 && line_str[line_str.length - 2] == '\r' && line_str[line_str.length - 1] == '\n') {
                            line_str = line_str[0 .. line_str.length - 2];
                        }
                        int chunk_length = line_str.to!int(16);
                        this.last_response = new ubyte[chunk_length];
                        socket.receive(this.last_response);
                    }
                }
                socket.close();
                return true;
            }
            return false;
        } catch (Exception ex) {
            writefln("Error sending IPP request: %s", ex.msg);
            return false;
        }
    }
} 

