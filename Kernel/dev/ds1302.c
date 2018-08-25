/*-----------------------------------------------------------------------*/
/* DS1202 and DS1302 Serial Real Time Clock driver                       */
/* 2014-12-30 Will Sowerbutts                                            */
/*-----------------------------------------------------------------------*/

#define _DS1302_PRIVATE

#include <kernel.h>
#include <kdata.h>
#include <stdbool.h>
#include <printf.h>
#include <rtc.h>
#include <ds1302.h>

void ds1302_send_byte(uint8_t byte)
{
    uint8_t i;

#ifdef DS1302_DEBUG
    kprintf("ds1302: send byte 0x%x\n", byte);
#endif
    /* drive the data pin */
    ds1302_set_pin_data_driven(true);

    /* clock out one byte, LSB first */
    for(i=0; i<8; i++){
        ds1302_set_pin_clk(false);
        /* for data input to the chip the data must be valid on the rising edge of the clock */
        ds1302_set_pin_data(byte & 1);
        byte >>= 1;
        ds1302_set_pin_clk(true);
    }
}

uint8_t ds1302_receive_byte(void)
{
    uint8_t i, b;

    /* tri-state the data pin */
    ds1302_set_pin_data_driven(false);

    /* clock in one byte, LSB first */
    b = 0;
    for(i=0; i<8; i++){
        ds1302_set_pin_clk(false);
        b >>= 1;
        /* data output from the chip is presented on the falling edge of each clock */
        /* note that output pin goes high-impedance on the rising edge of each clock */
        if(ds1302_get_pin_data())
            b |= 0x80;
        ds1302_set_pin_clk(true);
    }

    return b;
}

uint8_t uint8_from_bcd(uint8_t value)
{
    return (value & 0x0F) + (10 * (value >> 4));
}

void ds1302_read_clock(uint8_t *buffer, uint8_t length)
{
    uint8_t i;
    irqflags_t irq = di();

    ds1302_set_pin_ce(true);
    ds1302_send_byte(0x81 | 0x3E); /* burst read all calendar data */
    for(i=0; i<length; i++){
        buffer[i] = ds1302_receive_byte();
#ifdef DS1302_DEBUG
        kprintf("ds1302: received byte 0x%x index %d\n", buffer[i], i);
#endif
    }
    ds1302_set_pin_ce(false);
    ds1302_set_pin_clk(false);
    irqrestore(irq);
}

/* define CONFIG_RTC in platform's config.h to hook this into timer.c */
uint8_t platform_rtc_secs(void)
{
    uint8_t buffer;
    ds1302_read_clock(&buffer, 1);   /* read out only the seconds value */
    return uint8_from_bcd(buffer & 0x7F); /* mask off top bit (clock-halt) */
}

static uint8_t rtc_buf[8];

/* Full RTC support (for read - no write yet) */
int platform_rtc_read(void)
{
	uint16_t len = sizeof(struct cmos_rtc);
	uint16_t y;
	struct cmos_rtc cmos;
	uint8_t *p = cmos.data.bytes;

	if (udata.u_count < len)
		len = udata.u_count;

	ds1302_read_clock(rtc_buf, 7);

	y = rtc_buf[6];
	if (y > 0x70)
		y = 0x1900 | y;
	else
		y = 0x2000 | y;
	*p++ = y >> 8;
	*p++ = y;
	rtc_buf[4]--;		/* 0 based */
	if ((rtc_buf[4] & 0x0F) > 9)	/* Overflow case */
		rtc_buf[4] -= 0x06;
	*p++ = rtc_buf[4];	/* Month */
	*p++ = rtc_buf[3];	/* Day of month */
	if ((rtc_buf[2] & 0x90) == 0x90) {	/* 12hr mode, PM */
		/* Add 12 BCD */
		rtc_buf[2] += 0x12;
		if ((rtc_buf[2] & 0x0F) > 9)	/* Overflow case */
			rtc_buf[2] += 0x06;
	}
	*p++ = rtc_buf[2];	/* Hour */
	*p++ = rtc_buf[1];	/* Minute */
	*p = rtc_buf[0];	/* Second */
	cmos.type = CMOS_RTC_BCD;
	if (uput(&cmos, udata.u_base, len) == -1)
		return -1;
	return len;
}

int platform_rtc_write(void)
{
	udata.u_error = -EOPNOTSUPP;
	return -1;
}
