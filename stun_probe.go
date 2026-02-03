package main

import (
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"net"
	"time"
)

func main() {
	fmt.Println("[*] STUN probe started")

	server := "stun.l.google.com:19302"

	conn, err := net.Dial("udp", server)
	if err != nil {
		panic(err)
	}
	defer conn.Close()

	_ = conn.SetDeadline(time.Now().Add(3 * time.Second))

	req := make([]byte, 20)

	binary.BigEndian.PutUint16(req[0:2], 0x0001)
	binary.BigEndian.PutUint16(req[2:4], 0x0000)
	binary.BigEndian.PutUint32(req[4:8], 0x2112A442)

	_, _ = rand.Read(req[8:20])

	fmt.Println("[*] Sending STUN request...")
	_, err = conn.Write(req)
	if err != nil {
		panic(err)
	}

	buf := make([]byte, 1024)

	n, err := conn.Read(buf)
	if err != nil {
		fmt.Println("[!] No response (timeout or blocked UDP)")
		return
	}

	fmt.Printf("[+] STUN response received (%d bytes)\n", n)
	fmt.Printf("[+] Raw data: %x\n", buf[:n])
}
