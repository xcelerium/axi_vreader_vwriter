# AXI Virtual Reader and Writer

The AXI Virtual Reader and Writer perform AXI transfers to a specified address. It has four interfaces: a control interface, a response interface, an AXI Stream data interface, and an AXI interface. The control interface specifies transfer control information such as burst addresses and number of bytes to transfer. The AXI Stream data interface provides the write data (for the vwriter) and the read data (for the vreader). The response interface returns the status of the transfer.
