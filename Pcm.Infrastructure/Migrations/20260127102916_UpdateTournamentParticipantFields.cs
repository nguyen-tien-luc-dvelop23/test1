using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Pcm.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UpdateTournamentParticipantFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GroupName",
                table: "TournamentParticipants",
                type: "longtext",
                nullable: true)
                .Annotation("MySql:CharSet", "utf8mb4");

            migrationBuilder.AddColumn<int>(
                name: "TeamSize",
                table: "TournamentParticipants",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GroupName",
                table: "TournamentParticipants");

            migrationBuilder.DropColumn(
                name: "TeamSize",
                table: "TournamentParticipants");
        }
    }
}
