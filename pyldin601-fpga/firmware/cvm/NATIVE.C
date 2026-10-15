/* A nested PGM must not unload the VM which is executing its caller. */
main()
{
 system("B:RAMLOAD /L");
 system("B:RAMLOAD /U ZCODEVM");
 puts("CVM SYSTEM PASS");
}
