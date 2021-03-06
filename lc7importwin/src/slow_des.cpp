#include "stdafx.h"
#include "slow_des.h"



// Tables defined in the Data Encryption Standard documents

// Initial permutation IP
quint8 ip[] = {
	58, 50, 42, 34, 26, 18, 10, 2,
	60, 52, 44, 36, 28, 20, 12, 4,
	62, 54, 46, 38, 30, 22, 14, 6,
	64, 56, 48, 40, 32, 24, 16, 8,
	57, 49, 41, 33, 25, 17, 9, 1,
	59, 51, 43, 35, 27, 19, 11, 3,
	61, 53, 45, 37, 29, 21, 13, 5,
	63, 55, 47, 39, 31, 23, 15, 7
};

// Final permutation IP^-1
quint8 fp[] = {
	40, 8, 48, 16, 56, 24, 64, 32,
	39, 7, 47, 15, 55, 23, 63, 31,
	38, 6, 46, 14, 54, 22, 62, 30,
	37, 5, 45, 13, 53, 21, 61, 29,
	36, 4, 44, 12, 52, 20, 60, 28,
	35, 3, 43, 11, 51, 19, 59, 27,
	34, 2, 42, 10, 50, 18, 58, 26,
	33, 1, 41, 9, 49, 17, 57, 25
};

// expansion operation matrix
// This is for reference only; it is unused in the code
// as the f() function performs it implicitly for speed

/*
char ei[] = {
32, 1,   2,  3,  4,  5,
4,  5,   6,  7,  8,  9,
8,  9,  10, 11, 12, 13,
12, 13, 14, 15, 16, 17,
16, 17, 18, 19, 20, 21,
20, 21, 22, 23, 24, 25,
24, 25, 26, 27, 28, 29,
28, 29, 30, 31, 32,  1
};
*/

// permuted choice table (key)
quint8 pc1[] = {
	57, 49, 41, 33, 25, 17, 9,
	1, 58, 50, 42, 34, 26, 18,
	10, 2, 59, 51, 43, 35, 27,
	19, 11, 3, 60, 52, 44, 36,
	63, 55, 47, 39, 31, 23, 15,
	7, 62, 54, 46, 38, 30, 22,
	14, 6, 61, 53, 45, 37, 29,
	21, 13, 5, 28, 20, 12, 4
};

// number left rotations of pc1
quint8 totrot[] = {
	1, 2, 4, 6, 8, 10, 12, 14, 15, 17, 19, 21, 23, 25, 27, 28
};

// permuted choice key (table)
quint8 pc2[] = {
	14, 17, 11, 24, 1, 5,
	3, 28, 15, 6, 21, 10,
	23, 19, 12, 4, 26, 8,
	16, 7, 27, 20, 13, 2,
	41, 52, 31, 37, 47, 55,
	30, 40, 51, 45, 33, 48,
	44, 49, 39, 56, 34, 53,
	46, 42, 50, 36, 29, 32
};

// The (in)famous S-boxes
quint8 si[8][64] = {
	// S1
	{ 14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7,
	0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8,
	4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0,
	15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13 },

	// S2
	{ 15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10,
	3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5,
	0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15,
	13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9 },

	// S3
	{ 10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8,
	13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1,
	13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7,
	1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12 },

	// S4
	{ 7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15,
	13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9,
	10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4,
	3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14 },

	// S5 
	{ 2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9,
	14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6,
	4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14,
	11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3 },

	// S6 
	{ 12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11,
	10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8,
	9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6,
	4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13 },

	// S7
	{ 4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1,
	13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6,
	1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2,
	6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12 },

	// S8
	{ 13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7,
	1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2,
	7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8,
	2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11 }
};

// 32-bit permutation function P used on the output of the S-boxes
static quint8 p32i[] = {
	16, 7, 20, 21,
	29, 12, 28, 17,
	1, 15, 23, 26,
	5, 18, 31, 10,
	2, 8, 24, 14,
	32, 27, 3, 9,
	19, 13, 30, 6,
	22, 11, 4, 25
};

// End of DES-defined tables

// ---- Global Variables ------------------------------------------------

// Lookup tables initialized once only at startup by desinit()
quint32 sp[8][64];              // Combined S and P boxes
quint8 iperm[16][16][8];       // Initial permutations
quint8 fperm[16][16][8];       // Final permutations
//quint8 kn[16][8];              // 8 6-bit subkeys for each of 16 (we only use 15), initialized by setkey()

// Quick bit positions for nibbles and bytes
quint32 bytebit[] = { 0200, 0100, 040, 020, 010, 04, 02, 01 };
quint32 nibblebit[] = { 010,04,02,01 };

// Function Declarations

#ifndef  BIG_ENDIAN
// Byte swap a long 
unsigned long byteswap(unsigned long x)
{
	char *cp,tmp;
	cp = (char *)&x;
	tmp = cp[3];
	cp[3] = cp[0];
	cp[0] = tmp;
	tmp = cp[2];
	cp[2] = cp[1];
	cp[1] = tmp;
	return x;
}
#endif

// initialize a perm array
static void perminit(quint8 perm[16][16][8], quint8 p[64])
{
	int i,j,k,l,m;

	// Clear the permutation array
	for (i=0; i<16; i++) {
		for (j=0; j<16; j++) {
			// Clear permutation
			for (k=0; k<8; k++) {
				perm[i][j][k]=0;
			}

			// each input nibble position
			for (i=0; i<16; i++) {
				// each possible input nibble
				for (j = 0; j < 16; j++) {
					// each output bit position
					for (k = 0; k < 64; k++) {
						// where does this bit come from
						l = p[k] - 1; 

						// does it come from input posn
						if ((l >> 2) != i) continue;     // if not, bit k is 0

						// any such bit in input?
						if (!(j & nibblebit[l & 3])) continue;     

						// which bit is this in the byte?
						m = k & 07;   
						perm[i][j][k>>3] |= (char)bytebit[m];
					}
				}
			}
		}
	}
}

// Initialize the lookup table for the combined S and P boxes
static void spinit()
{
	quint8 pbox[32];
	quint32 p,i,s,j,rowcol;
	quint32 val;

	// Compute pbox, the inverse of p32i.
	// This is easier to work with

	for(p=0;p<32;p++){
		for(i=0;i<32;i++){
			if(p32i[i]-1 == p){
				pbox[p] = (char)i;
				break;
			}
		}
	}

	// For each S-box
	for(s = 0; s < 8; s++) {  
		// For each possible input
		for(i=0; i<64; i++) {
			val = 0;

			// The row number is formed from the first and last
			// bits; the column number is from the middle 4

			rowcol = (i & 32) | ((i & 1) ? 16 : 0) | ((i >> 1) & 0xf);
			for(j=0;j<4;j++) {       // For each output bit
				if(si[s][rowcol] & (8 >> j)){
					val |= 1L << (31 - pbox[4*s + j]);
				}
			}
			sp[s][i] = val;
		}
	}
}

// desinit: Allocate space and initialize DES lookup arrays
void slowdes_init()
{
	spinit();
	perminit(iperm, ip);
	perminit(fperm, fp);
}



// permute: takes an input block, passes it through a permutation
void slowdes_permute(const quint8 inblock[8], const quint8 perm[16][16][8], quint8 outblock[8])
{
	register int i,j;
	const quint8 *ib,*p,*q;
	quint8 *ob;

	// Clear Output block
	memset(outblock, 0, 8*sizeof(char));

	// Perform permutation
	ib = inblock;
	for (j = 0; j < 16; j += 2, ib++) { // for each input nibble
		ob = outblock;
		p = perm[j][(*ib >> 4) & 017];
		q = perm[j + 1][*ib & 017];
		for (i = 8; i != 0; i--){   // and each output byte 
			*ob++ |= *p++ | *q++;   // OR the masks together
		}
	}
}

//* The nonlinear function f(r,k), the heart of DES
long f(quint32 r, quint8 subkey[8])
{
	quint32 rval, rt;

	// Run E(R) ^ K through the combined S & P boxes
	// This code takes advantage of a convenient regularity in
	// E, namely that each group of 6 bits in E(R) feeding
	// a single S-box is a contiguous segment of R.

	rt = (r >> 1) | ((r & 1) ? 0x80000000 : 0);
	rval = 0;
	rval |= sp[0][((rt >> 26) ^ *subkey++) & 0x3f];
	rval |= sp[1][((rt >> 22) ^ *subkey++) & 0x3f];
	rval |= sp[2][((rt >> 18) ^ *subkey++) & 0x3f];
	rval |= sp[3][((rt >> 14) ^ *subkey++) & 0x3f];
	rval |= sp[4][((rt >> 10) ^ *subkey++) & 0x3f];
	rval |= sp[5][((rt >> 6) ^ *subkey++) & 0x3f];
	rval |= sp[6][((rt >> 2) ^ *subkey++) & 0x3f];
	rt = (r << 1) | ((r & 0x80000000) ? 1 : 0);
	rval |= sp[7][(rt ^ *subkey) & 0x3f];

	return rval;
}

// round: Do one DES cipher round 
void slowdes_round(SLOWDES_CTX *fdctx, quint32 num, quint32 *block)
{
	// The rounds are numbered from 0 to 15. On even rounds
	// the right half is fed to f() and the result exclusive-ORs
	// the left half; on odd rounds the reverse is done.

	if(num & 1)
		block[1] ^= f(block[0],fdctx->kn[num]);
	else 
		block[0] ^= f(block[1],fdctx->kn[num]);
}

// In-place encryption of 64-bit block
void slowdes_endes(SLOWDES_CTX *fdctx, quint8 block[8])
{
	int i;
	quint8 work[8];
	long tmp;

	// Initial Permutation
	slowdes_permute(block, iperm, work);   

#ifndef BIG_ENDIAN
	((quint32 *)work)[0] = byteswap(((quint32 *)work)[0]);
	((quint32 *)work)[1] = byteswap(((quint32 *)work)[1]);
#endif

	// Do the 16 rounds
	for (i=0; i<16; i++) 
		slowdes_round(fdctx, i,(quint32 *)work);

	// Left/right half swap
	tmp = ((quint32 *)work)[0];
	((quint32 *)work)[0] = ((quint32 *)work)[1];
	((quint32 *)work)[1] = tmp;

	// Inverse initial permutation
#ifndef BIG_ENDIAN
	((quint32 *)work)[0] = byteswap(((quint32 *)work)[0]);
	((quint32 *)work)[1] = byteswap(((quint32 *)work)[1]);
#endif	
	slowdes_permute(work, fperm, block);
}

// In-place decryption of 64-bit block 
void slowdes_dedes(SLOWDES_CTX *fdctx, quint8 block[8])
{
	int i;
	quint8 work[8];
	quint32 tmp;

	// Initial permutation
	slowdes_permute(block,iperm,work);    
#ifndef BIG_ENDIAN
	((quint32 *)work)[0] = byteswap(((quint32 *)work)[0]);
	((quint32 *)work)[1] = byteswap(((quint32 *)work)[1]);
#endif

	// Left/right half swap
	tmp = ((quint32 *)work)[0];
	((quint32 *)work)[0] = ((quint32 *)work)[1];
	((quint32 *)work)[1] = tmp;

	// Do the 16 rounds in reverse order
	for (i=15; i >= 0; i--)
		slowdes_round(fdctx,i,(quint32 *)work);

	// Inverse initial permutation
#ifndef BIG_ENDIAN
	((quint32 *)work)[0] = byteswap(((quint32 *)work)[0]);
	((quint32 *)work)[1] = byteswap(((quint32 *)work)[1]);
#endif
	slowdes_permute(work,fperm,block);    
}

// setkey:
// initializes key schedule array
// key is 64 bits (will use only 56)
void slowdes_setkey(SLOWDES_CTX *fdctx, quint8 *key)
{
	quint8 pc1m[56];              // place to modify pc1 into 
	quint8 pcr[56];               // place to rotate pc1 into 
	register quint32 i,j,l,m;

	memset(fdctx->kn,0,sizeof(fdctx->kn));

	for (j=0; j<56; j++) {      // convert pc1 to bits of key 
		l=pc1[j]-1;             // integer bit location  
		m = l & 07;             // find bit              
		pc1m[j] = (quint8)((key[l >> 3] &    // find which key byte l is in 
			bytebit[m])     // and which bit of that byte 
			? 1 : 0);       // and store 1-bit result
	}

	for (i=0; i<16; i++) {      // key chunk for each iteration
		for (j=0; j<56; j++)    // rotate pc1 the right amount
			pcr[j] = pc1m[(l=j+totrot[i])<(j<28? 28 : 56) ? l: l-28];		
		// rotate left and right halves independently
		for (j=0; j<48; j++) {   // select bits individually
			// check bit that goes to kn[j]
			if (pcr[pc2[j]-1]) {
				// mask it in if it's there
				l= j % 6;
				fdctx->kn[i][j / 6] |= (quint8)(bytebit[l] >> 2);
			}
		}
	}

}

void slowdes_str_to_key(const char *str, quint8 key[8])
{
	const quint8 *ustr=(const quint8 *) str;
	key[0] = (ustr[0]>>1)<<1;
	key[1] = (((ustr[0]&0x01)<<6) | (ustr[1]>>2))<<1;
	key[2] = (((ustr[1]&0x03)<<5) | (ustr[2]>>3))<<1;
	key[3] = (((ustr[2]&0x07)<<4) | (ustr[3]>>4))<<1;
	key[4] = (((ustr[3]&0x0F)<<3) | (ustr[4]>>5))<<1;
	key[5] = (((ustr[4]&0x1F)<<2) | (ustr[5]>>6))<<1;
	key[6] = (((ustr[5]&0x3F)<<1) | (ustr[6]>>7))<<1;
	key[7] = (ustr[6]&0x7F)<<1;
}
