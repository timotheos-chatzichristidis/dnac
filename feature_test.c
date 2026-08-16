/* feature_test - measure whether an "orientation" lens carries predictive signal.
 *
 * The user's idea: classify each dinucleotide (x,y) by an inversion bit
 *   ob(x,y) = (x <= y) ? 0 : 1     with order A<C<G<T   (AC=0, CA=1, GT=0, TG=1)
 * and model the recent HISTORY of those bits as context for the next base.
 *
 * Honest test: for the SAME context size in bits, does the lens predict the next
 * base with lower conditional entropy than plain raw bases? We compare
 *   raw order-R            (2*R context bits)
 *   derived: last 2 bases + L orientation bits   (4 + L context bits)
 * Lower bits/base = more predictive. If derived beats raw at equal bits, the lens
 * genuinely exposes structure; if it loses, it is redundant/cosmetic.
 *
 * Build: gcc -O2 -Wall -o feature_test feature_test.c -lm
 * Use:   feature_test <fasta>
 */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

static int b2s(int c){ switch(c){case 'A':return 0;case 'C':return 1;case 'G':return 2;case 'T':return 3;} return -1; }

/* conditional entropy (bits/base) of next symbol given a context with `cells` values */
static double entropy_from_counts(uint32_t *cnt, size_t cells) {
    double bits = 0.0; double total = 0.0;
    for (size_t c = 0; c < cells; c++) {
        uint32_t *n = &cnt[c*4];
        double T = (double)n[0]+n[1]+n[2]+n[3];
        if (T <= 0) continue;
        total += T;
        for (int s=0;s<4;s++) if (n[s]) bits += (double)n[s] * log2(T/(double)n[s]);
    }
    return total>0 ? bits/total : 0.0;
}

/* raw order-R model: context = last R bases (2*R bits) */
static double measure_raw(const uint8_t *seq, size_t n, int R) {
    size_t cells = (size_t)1 << (2*R);
    uint32_t *cnt = calloc(cells*4, sizeof(uint32_t));
    if (!cnt) { fprintf(stderr,"oom R=%d\n",R); return -1; }
    uint64_t mask = cells - 1;
    uint64_t ctx = 0;
    for (size_t i=0;i<n;i++){
        if (i>=(size_t)R) cnt[(ctx & mask)*4 + seq[i]]++;
        ctx = (ctx<<2) | seq[i];
    }
    double h = entropy_from_counts(cnt, cells);
    free(cnt);
    return h;
}

/* derived model: context = last 2 bases (4 bits) + last L orientation bits */
static double measure_derived(const uint8_t *seq, size_t n, int L) {
    int ctxbits = 4 + L;
    size_t cells = (size_t)1 << ctxbits;
    uint32_t *cnt = calloc(cells*4, sizeof(uint32_t));
    if (!cnt) { fprintf(stderr,"oom L=%d\n",L); return -1; }
    /* rolling orientation-bit history: ob for the pair ending at position j */
    uint64_t ob = 0;            /* bit 0 = most recent orientation bit */
    uint64_t obmask = ((uint64_t)1 << L) - 1;
    size_t start = (size_t)(L+2);
    for (size_t i=1;i<n;i++){
        /* before counting position i, ob holds bits for pairs ending at i-1,i-2,... */
        if (i>=start){
            uint64_t ctx2 = (uint64_t)seq[i-2]*4 + seq[i-1];   /* 4 bits */
            uint64_t ctx = (ctx2 << L) | (ob & obmask);
            cnt[ctx*4 + seq[i]]++;
        }
        /* update ob with the pair ending at i: (seq[i-1], seq[i]) */
        int newob = (seq[i-1] <= seq[i]) ? 0 : 1;
        ob = (ob<<1) | (uint64_t)newob;
    }
    double h = entropy_from_counts(cnt, cells);
    free(cnt);
    return h;
}

int main(int argc, char**argv){
    if (argc<2){ fprintf(stderr,"usage: feature_test <fasta>\n"); return 1; }
    FILE *f = fopen(argv[1],"rb");
    if (!f){ perror("open"); return 1; }
    fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET);
    uint8_t *raw = malloc(sz); if(fread(raw,1,sz,f)!=(size_t)sz){perror("read");return 1;} fclose(f);
    uint8_t *seq = malloc(sz); size_t n=0;
    for (long i=0;i<sz;i++){ int s=b2s(raw[i]); if(s>=0) seq[n++]=(uint8_t)s; }
    free(raw);
    printf("bases: %zu\n\n", n);
    printf("%-34s %s\n","context","bits/base");
    printf("%-34s %.4f\n","order-1 (2 bits)",  measure_raw(seq,n,1));
    printf("%-34s %.4f\n","order-2 (4 bits) [baseline]", measure_raw(seq,n,2));
    printf("\n-- 12-bit contexts (fair fight) --\n");
    printf("%-34s %.4f\n","raw order-6",          measure_raw(seq,n,6));
    printf("%-34s %.4f\n","derived 2 bases + 8 ob", measure_derived(seq,n,8));
    printf("\n-- 20-bit contexts (fair fight) --\n");
    printf("%-34s %.4f\n","raw order-10",          measure_raw(seq,n,10));
    printf("%-34s %.4f\n","derived 2 bases + 16 ob", measure_derived(seq,n,16));
    free(seq);
    return 0;
}
