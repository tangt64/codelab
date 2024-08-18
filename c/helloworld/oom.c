#include <stdio.h>
#include <stdlib.h>

#define CR 13

int main(){
   char *fptr;
   long i, k;

   i = 50000000000L;

   do{
      if(( fptr = (char *)malloc(i)) == NULL){
         i = i - 1000;
      }
   }
   while (( fptr == NULL) && (i > 0));

   sleep(15);
   for(k = 0; k < i; k++){
      fptr[k] = (char) (k & 255);
   }
   sleep(60);
   free(fptr);
   return(0);
}